% Create B0 fieldmaps (in Hz) and unwarped T2w mag images for each subject
%
% AUTHOR : Mike Tyszka
% PLACE  : Caltech Brain Imaging Center
% DATES  : 2020-01-27 JMT From scratch

% Setup parallel pool
if isempty(gcp('nocreate')), parpool; end

% Custom shell with full environment setup
shell = '/Users/jmt/bin/bash_matlab.sh';

% Key directories
root_dir = '/Volumes/Data/jmt/Conte/Anita_Conte_LOI';
src_dir = fullfile(root_dir, 'sourcedata');

% Load the subject list from CSV
C = table2cell(readtable('subject_list.csv'));

% Loop over subject list
parfor sc = 1:length(C)
    
    src_subj_dir = fullfile(src_dir, C{sc,1});
    
    fprintf('\n');
    fprintf('Generating TOPUP fieldmap for %s\n', C{sc, 1});
    
    raw_dir = fullfile(src_subj_dir, 'raw');
    
    % Find SE-EPI pair in <subject>/raw/ folder
    AP_file = files(fullfile(raw_dir, 'EP*dir-AP_epi*', '*dir_ap_epi.nii'));
    PA_file = files(fullfile(raw_dir, 'EP*dir-PA_epi*', '*dir_pa_epi.nii'));
    
    % Get ETL from AP sidecar
    if isempty(AP_file)
        
        fprintf('* Echo train not determined - skipping this subject\n');
        
    else
        
        % Convert to strings
        AP_fname = AP_file{1};
        PA_fname = PA_file{1};
        
        AP_path = fileparts(AP_fname);
        AP_info_path = fullfile(AP_path, 'dicominfo.mat');
        AP_info = load(AP_info_path);
        ETL = double(AP_info.dcminfo.unwarpinfo.readouttime) * 1.0e-3;
    
        % Create new fieldmap directory in <subject>/raw/
        fmap_dir = fullfile(raw_dir, 'EP_fieldmap');
        if ~isfolder(fmap_dir), mkdir(fmap_dir); end

        % Construct TOPUP parameter file
        pars_fname = fullfile(fmap_dir, 'fadolphs_fieldmap.pars');
        
        if isfile(pars_fname)
            fprintf('*  TOPUP parameter file exists - skipping creation\n');
        else
            fprintf('  Constructing TOPUP parameter file %s\n', pars_fname);
            fd = fopen(pars_fname, 'w');
            fprintf(fd, '0 -1 0 %0.5f\n', ETL);
            fprintf(fd, '0  1 0 %0.5f\n', ETL);
            fclose(fd);
        end
        
        % Concatenate AP and PA images into 4D image for TOPUP
        both_fname = fullfile(fmap_dir, 'fadolphs_fieldmap_both.nii');
        
        if isfile(both_fname)
            fprintf('*  4D SE-EPI image exists - skipping creation\n');
        else
            fprintf('  Merging SE-EPI fieldmaps into single 4D image\n');
            cmd = sprintf('%s fslmerge -t %s %s %s', shell, both_fname, AP_fname, PA_fname);
            system(cmd);
        end

        % Run TOPUP to generate B0 fieldmap estimate in Hz
        fmap_fname = fullfile(fmap_dir, 'fadolphs_fieldmap_Hz.nii');
        uw_fname = fullfile(fmap_dir, 'fadolphs_unwarped.nii');

        if isfile(fmap_fname) && isfile(uw_fname)
            fprintf('*  TOPUP fieldmap exists - skipping creation\n');
        else
            fprintf('  Running TOPUP fieldmap reconstruction\n');
            cmd = sprintf('%s topup --imain=%s --datain=%s --fout=%s --iout=%s', ...
                shell, both_fname, pars_fname, fmap_fname, uw_fname);
            system(cmd);
        end
        
        % Average unwarped image pair for use as a mag reference
        mag_fname = fullfile(fmap_dir, 'fadolphs_fieldmap_mag.nii');
        
        if isfile(mag_fname)
            fprintf('*  Fieldmap magnitude image exists - skipping creation\n');
        else
            fprintf('  Creating fieldmap magnitude image\n');
            cmd = sprintf('%s fslmaths %s -Tmean %s', shell, uw_fname, mag_fname);
            system(cmd);
        end
        
        % Convert Hz to radians for a dummy TE difference of 1.0 ms
        phs_fname = fullfile(fmap_dir, 'fadolphs_fieldmap_phs.nii');

        % Scale Hz fmap by 2 * pi * dTE
        fmap_dTE = 1e-3;  % Dummy echo time difference in seconds
        Hz2rads = 2.0 * pi * fmap_dTE;
        
        if isfile(phs_fname)
            fprintf('*  Fieldmap phase image exists - skipping creation\n');
        else
            fprintf('  Creating fieldmap phase image (scale by %0.6f)\n', Hz2rads);
            cmd = sprintf('%s fslmaths %s -mul %f %s', shell, fmap_fname, Hz2rads, phs_fname);
            system(cmd);
        end
        
    end
    
end

% Delete parallel pool
delete(gcp('nocreate'));