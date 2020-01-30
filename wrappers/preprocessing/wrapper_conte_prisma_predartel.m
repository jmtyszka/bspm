% 2020-01-28 Mike Tyszka Adapt Bob's wrapper_conte_predartel.m for Conte Core on Prisma

fprintf('--------\n');
fprintf('Conte Core Prisma LOI Preprocessing Pipeline\n');
fprintf('--------\n');

% | options
runit.omitvols      = 1;
runit.slicetime     = 1;
opt.slice_times     = 1; % 1 do slice-timing using actual times, 0 will do using order
opt.coreg_epi2t1    = 1; % 0 will coreg t1 to mean EPI; 1 will coreg all EPI to t1
runit.segment       = 0;
omitpat             = '';
saveit              = 1;
append2jobname      = 'CONTE_PRISMA_PREDARTEL';

% | paths for relevant folders
path.study  = '/Users/jmt/Data/Conte/Anita_Conte_LOI/sourcedata';
path.qa     = fullfile(path.study, '_notes_', 'qa');
if ~exist(path.qa, 'dir'), mkdir(path.qa); end

% | patterns for finding relevant files/folders (relative to subject dir)
pattern = struct( ...
    'subdir',   'CC*', ...
    'epidir',   'EP*task-socnsloi2_bold*', ...
    't1dir',    'GR_T1w*', ...
    'fmdir',    'EP_fieldmap', ...
    'anatimg',  'sadolphs*t1w_combecho.nii', ...
    'fmimg',    'fadolphs_fieldmap_*.nii', ...
    'epiimg',   'fadolphs*nii', ...
    'refdcm',   'refdcm_conte_prisma_epi_socns.dcm' ...
    );

% | Field Map Parameters
epi_etl = 42.58;  % Effective EPI echo train duration in ms. Use value from dcm2niix
blip = -1;  % Determine by inspection of unwarped EPIs
jacob = 0;  % No Jacobian signal correction during unwarping

% | reference dicom image
fprintf('Identifying reference DICOM for EPIs\n');
refdcm = bspm_dicomref(pattern.refdcm);

% | relevant directories
subdirs = files(fullfile(path.study, pattern.subdir));
if ~isempty(omitpat), subdirs(cellstrfind(subdirs, omitpat)) = []; end

% | Omit Initial Volumes
if runit.omitvols
    fprintf('Excluding initial volumes\n');
    omitpat = {'fad*_00001.nii' 'fad*_00002.nii' 'fad*_00003.nii' 'fad*_00004.nii'};
    bspm_omit_vols(fullfile(path.study, pattern.subdir, 'raw', pattern.epidir), omitpat);
end

% | Build Jobs Subject-by-Subject
allsub = cell(length(subdirs), 1);
count   = 0;

for s = 1:length(subdirs)

    subdir = subdirs{s};
    [ps, sub, ext] = fileparts(subdir);
    
    fprintf('\n');
    fprintf('Working on %s\n', sub); 

    % | make sure EPIs are all the same dimension and orientations
    fprintf('  Checking functional EPI orientations\n');
    [flag, volinfo] = bspm_check_orientations(files(fullfile(subdir, 'raw', pattern.epidir, pattern.epiimg)), 1);
    
    if flag
        fprintf('\n - Check Images for %s! Skipping to Next Subject', sub);
        continue;
    end

    % | grab epi directories
    fprintf('  Grabbing EPI directories\n');
    epidirs = files([subdir filesep 'raw' filesep pattern.epidir]);
    epi_all = cell(size(epidirs));
    qa_epis = epi_all;
    qa_runnames = epi_all;
    vox_disp_map = epi_all;
    uaepi = [];
    
    % Locate fieldmap magnitude and phase images
    fmap_dir = fullfile(subdir, 'raw', pattern.fmdir);
    fmap_mag = files(fullfile(fmap_dir, 'fadolphs_*fieldmap_mag.nii'));
    fmap_hz = files(fullfile(fmap_dir, 'fadolphs_*fieldmap_Hz.nii'));
    
    % Extract path, filename and extension of fieldmap phase image
    [pmapp, pmapn, pmape] = fileparts(fmap_hz{1});
    
    n_epi = length(epidirs);
    
    if n_epi > 1
        
        % Preallocate cell array
        allepi = cell(n_epi, 1);
        
        for i = n_epi
            allepi{i} = files([epidirs{i} filesep pattern.epiimg]);
        end
        
        allepi1 = cellfun(@(x) x{1}, allepi, 'unif', false);
        
        flag = bspm_check_orientations(allepi1, 0);
        if flag
            bspm_reorient(vertcat(allepi{2:end}), allepi{1}{1});
        end
        
    end

    for e = 1:length(epidirs)
        
        fprintf('  Working on %s\n', epidirs{e});

        % | Define EPIs
        epi = files([epidirs{e} filesep pattern.epiimg]);
        [epip, epin, epie] = cellfun(@fileparts, epi, 'unif', false);
        pat1 = {'' 'a'};
        pat2 = {'u' 'ua'};
        epi_st = strcat(epip, filesep, pat1{runit.slicetime+1}, epin, epie);
        epi_uw = strcat(epip, filesep, pat2{runit.slicetime+1}, epin, epie);

        % | Slice Timing
        if runit.slicetime
            count = count + 1;
            fprintf('    Slice timing correction\n');
            matlabbatch(count) = bspm_slicetime(epi, refdcm, opt.slice_times+1);
        end

        % | Save Volumes for Realign and Unwarp
        epi_all{e} = epi_st;
        
        if length(epidirs) == 1
            vox_disp_map{e} = strcat(pmapp, filesep, 'vdm5_', pmapn, pmape);
        else
            vox_disp_map{e} = strcat(pmapp, filesep, 'vdm5_', pmapn, sprintf('_run%d', e), pmape);
        end
        
        epi_first{e} = epi_st{1};
        qa_epis{e} = epi_uw{1};
        
        if e == 1
            [ep, en, ee] = fileparts(epi_uw{1});
            mean_epi = strcat(ep, filesep, 'mean', en, ee);
        end
        
        [ps, name, ext] = fileparts(epidirs{e});
        qa_runnames{e} = name;

        % | Save FileNames for Coregistration to T1
        uaepi = [uaepi; epi_uw];

    end

    % | TOPUP Field Map preparation
    count = count + 1;
    fprintf('  Preparing fieldmap\n');
    matlabbatch(count) = bspm_topup_fieldmap(fmap_mag, fmap_hz, ...
        epi_first, epi_etl, 'blip', blip, 'jacob', jacob);
    
    % | Realign and Unwarp
    count = count + 1;
    fprintf('  Preparing realign and unwarp\n');
    matlabbatch(count) = bspm_realign_and_unwarp(epi_all, vox_disp_map);

    % | Co-register
    fprintf('  Preparing coregistration\n');
    t1 = files([subdir filesep 'raw' filesep pattern.t1dir filesep pattern.anatimg]);
    count = count + 1;
    
    if opt.coreg_epi2t1
        
        % | EPIs to T1
        fprintf('    Coregister EPIs to T1\n');
        matlabbatch(count) = bspm_coregister(t1, mean_epi, uaepi);
        
    else
        
        % | T1 to Mean EPI
        fprintf('    Coregister T1 to mean EPI\n');
        matlabbatch(count) = bspm_coregister(mean_epi, t1);
        
    end

    % | Segment T1
    if runit.segment
        count = count + 1;
        fprintf('  Preparing T1 segmentation\n');
        matlabbatch(count) = bspm_segment(t1);
    end

end
fprintf('\n');

% | Save Job
if saveit
    if isempty(append2jobname)
        jobname = fullfile(pwd, sprintf('job_pp_%s.mat', strtrim(datestr(now,'mmm_DD_YYYY'))));
    else
        jobname = fullfile(pwd, sprintf('job_pp_%s_%s.mat', strtrim(datestr(now,'mmm_DD_YYYY')), append2jobname));
    end
    save(jobname, 'matlabbatch');
end

% | Run the job
spm_jobman('initcfg');
spm_jobman('run', matlabbatch);





