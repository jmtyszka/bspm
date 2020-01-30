function allinput = wrapper_level1_loisocns_blockwise(covidx, varargin)
    % matlabbatch = wrapper_level1_loisocns_blockwise(covidx, varargin)
    %
    % To show default settings, run without any arguments.
    %
    %     COVIDX
    %       01 - Duration
    %       02 - Errors (Total)
    %       03 - Errors (Foils)
    %

    % | SET DEFAULTS AND PARSE VARARGIN
    % | ===========================================================================
    defaults = {
            'armethod',    2,                                                  ...
                'basename',         'SOCNS_LOI2',             ...
                'behavid',          'socns_loi2*mat',            ...
            'brainmask',   bspm_brainmask,                                      ...
            'epifname',    [],                                                 ...
            'epipat',           's6w2*nii',             ...
            'fcontrast',   0,                                                  ...
            'HPF',         100,                                                ...
            'is4D',        1,                                                  ...
            'maskthresh',  0.40,                                               ...
            'model',       'BLOCKWISE',                                        ...
            'nskip',       4,                                                  ...
            'nuisancepat', 'badscan*txt',                                          ...
            'runid',       'EP*LOI_2*',                                          ...
            'runtest',     0,                                                  ...
                'studydir',         '/Users/bobspunt/Documents/fmri/conte_socbat', ...
            'subid',       'CC*',                                              ...
            'TR',          1,                                                ...
            'yesnokeys',   [1                                                  2]  ...
                };
    vals = setargs(defaults, varargin);
    if nargin==0, mfile_showhelp; fprintf('\t= DEFAULT SETTINGS =\n'); disp(vals); return; end
    fprintf('\n\t= CURRENT SETTINGS =\n'); disp(vals);

    % | PATHS
    % | ===========================================================================
    if strfind(pwd,'/home/spunt'), studydir = '/home/spunt/data/conte'; end
    [subdir, subnam] = files([studydir filesep subid]);

    % | EPI FNAME
    % | ===========================================================================
    if ~isempty(epifname)
        epifname = fullfile(studydir, epifname);
        if exist(epifname, 'file')
            fnepi = load(epifname);
        else
            disp('epifname could not be found!');
            fnepi = [];
        end
    else
        fnepi = [];
    end

    % | ANALYSIS NAME
    % | ===========================================================================
    armethodlabels  = {'NoAR1' 'AR1' 'WLS'};
    covnames        = {'Duration' 'Errors' 'FoilErrors'};
    if ~isempty(covidx)
        pmnames         = regexprep(covnames(covidx), '_', '');
        pmstr           = sprintf(repmat('_%s', 1, length(pmnames)), pmnames{:}); pmstr(1)= [];
    else
        pmstr = 'None';
    end

    analysisname  = sprintf('%s_%s_Pmodby_%s_%s_%ds_ImpT%d_%s', basename, model, ...
                            pmstr, armethodlabels{armethod + 1}, HPF, maskthresh*100, bob_timestamp);
    printmsg(analysisname, 'msgtitle', 'Analysis Name');

    % | IMAGING PARAMETERS
    % | ========================================================================
    adjons          = TR*nskip;

    % | RUNTIME OPTIONS
    % | ===========================================================================
    if runtest, subdir = subdir(1); end

    % | SUBJECT LOOP
    % | ===========================================================================
    allinput = [];
    for s = 1:length(subdir)

        % | Check Subject and Define Folders
        % | ========================================================================
        rundir      = files([subdir{s} filesep 'raw' filesep runid]);
        if isempty(rundir), printmsg('Valid run directory not found, moving on...', 'msgtitle', subnam{s}); continue; end
        analysisdir = fullfile(subdir{s}, 'analysis', analysisname);
        if any([exist(fullfile(analysisdir, 'mask.img'), 'file') exist(fullfile(analysisdir, 'mask.nii'), 'file')])
            printmsg('Level 1 job probably already estimated, moving on...', 'msgtitle', subnam{s}); continue;
        end
        printmsg(sprintf('Building Level 1 Job for %d Runs', length(rundir)),'msgtitle', subnam{s});

        % | Behavioral and Nuisance Regressor Files
        % | ========================================================================
        nuisance    = files([subdir{s} filesep 'raw' filesep runid filesep nuisancepat]);
        behav       = files([subdir{s} filesep 'behav' filesep behavid]);

        % | Get Images
        % | ========================================================================
        images          = cell(size(rundir));
        if ~isempty(fnepi)
            subidx = strcmp(fnepi.subname, subnam{s});
            images = fnepi.epifname(subidx);
        else
            for r = 1:length(rundir)
                images{r} = files([rundir{r} filesep epipat]);
                if isempty(images{r})
                    error('\nImage data not found! Failed search pattern:\n%s', [rundir{r} filesep epipat]);
                end
            end
        end

        % | Run Loop
        % | ========================================================================
        for r = 1:length(rundir)

            % | Data for Current Run
            % | =====================================================================
            b = get_behavior(behav{r}, model, yesnokeys);
            b.blockwise(:,3) = b.blockwise(:,3) - adjons;

            % | Sort by condlabel so betas refer to same block for all subjects
            % | =====================================================================
            data = [b.condlabels num2cell(b.blockwise)];
            data = sortrows(data, -1);
            b.condlabels = data(:,1);
            b.blockwise = cell2mat(data(:,2:end));

            % | Columns for b.blockwise
            % | =====================================================================
            % 1 - Block
            % 2 - Cond
            % 3 - Onset
            % 4 - Duration
            % 5 - Total_Errors
            % 6 - Foil_Errors

            % | Conditions
            % | =====================================================================
            for c = 1:length(b.condlabels)
                runs(r).conditions(c).name      = b.condlabels{c};
                runs(r).conditions(c).onsets    = b.blockwise(c, 3);
                runs(r).conditions(c).durations = b.blockwise(c, 4);
            end

            % | Floating Parametric Modulators
            % | =====================================================================
            if ~isempty(covidx)
                allpm           = b.blockwise(:,4:6);
                modelpm         = allpm(:,covidx);
                modelpmnames    = pmnames;
                novaridx = find(nanstd(modelpm)==0);
                if ~isempty(novaridx), modelpm(:,novaridx) = []; modelpmnames(novaridx) = []; end
                for p = 1:length(modelpmnames)
                    runs(r).floatingpm(p).name = modelpmnames{p};
                    runs(r).floatingpm(p).onsets = b.blockwise(:,3);
                    runs(r).floatingpm(p).durations = b.blockwise(:,4);
                    runs(r).floatingpm(p).values = modelpm(:,p);
                end
            end

        end
        if length(rundir)==1
            images = images{1};
            if iscell(nuisance), nuisance = nuisance{1}; end
        end

        % | General Information
        % | ========================================================================
        general_info.analysis           = analysisdir;
        general_info.is4D               = is4D;
        general_info.TR                 = TR;
        general_info.hpf                = HPF;
        general_info.autocorrelation    = armethod;
        general_info.nuisance_file      = nuisance;
        general_info.brainmask          = brainmask;
        general_info.maskthresh         = maskthresh;
        general_info.hrf_derivs         = [0 0];
        general_info.mt_res             = 16;
        general_info.mt_onset           = 8;

        % | Contrasts
        % | ========================================================================
        ncond   = length(b.condlabels);
        cond    = b.blockwise(:,2)';
        w(1,:)      = (ismember(cond, [2 3]) - ismember(cond, [5 6]));
        w(2,:)      = (ismember(cond, [1]) - ismember(cond, [4]));
        w(3,:)      = (ismember(cond, [2]) - ismember(cond, [5]));
        w(4,:)      = (ismember(cond, [3]) - ismember(cond, [6]));
        w(5,:)      = (ismember(cond, [2 3])/2 - ismember(cond, [1]));
        w(6,:)      = (ismember(cond, [2 3 5 6])/2 - ismember(cond, [1 4]));
        w(7,:)      = (ismember(cond, [2 3 4]) - ismember(cond, [1 5 6]));
        w(8,:)      = (ismember(cond, [2 4]) - ismember(cond, [1 5]));
        w(9,:)      = (ismember(cond, [3 4]) - ismember(cond, [1 6]));


        wpos = w; wpos(w<0) = 0;
        wneg = w; wneg(w>0) = 0;
        wpos = wpos./repmat(sum(wpos, 2), 1, size(w, 2));
        wneg = wneg./repmat(sum(wneg, 2), 1, size(w, 2));
        weights = wpos - wneg;
        ncon    = size(weights,1);
        conname = {'SOC_Why_-_How' 'NS_Why_-_How' 'Face_Why_-_How' 'Hand_Why_-_How' 'SOC_Why_-_NS_Why' 'SOC_Why+How_-_NS_Why+How' 'SOC_Why-How_-_NS_Why-How' 'Face_Why-How_-_NS_Why-How' 'Hand_Why-How_-_NS_Why-How'};
        for c = 1:ncon
            contrasts(c).type       = 'T';
            contrasts(c).weights    = weights(c,:);
            contrasts(c).name       = conname{c};
        end
        if fcontrast
            contrasts(ncon+1).type      = 'F';
            contrasts(ncon+1).name      = 'Omnibus';
            contrasts(ncon+1).weights   = eye(ncond);
        end

        % | Make Job
        % | ========================================================================
        allinput{s} = bspm_level1(images, general_info, runs, contrasts);

        % | Cleanup Workspace
        % | ========================================================================
        clear general_info runs contrasts b modelpm modelpmnames

    end
    end
% =========================================================================
% * SUBFUNCTIONS
% =========================================================================
function b = get_behavior(in, opt, yesnokeys)
    % GET_BEHAVIOR
    %
    %   USAGE: b = get_behavior(in, opt)
    %
    %       in      behavioral data filename (.mat)
    %       opt     '2x2'  - full design
    %               '1x2'  - why vs. how
    %
    %       Columns for b.blockwise
    %          1 - Block
    %          2 - Cond
    %          3 - Onset
    %          4 - Duration
    %          5 - Total_Errors
    %          6 - Foil_Errors
    %
    % CREATED: Bob Spunt, Ph.D. (bobspunt@gmail.com) - 2014.02.24
    % =========================================================================
    if nargin < 1, error('USAGE: b = get_behavior(in, opt, yesnokeys)'); end
    if nargin < 2, opt = '2x2'; end
    if nargin < 3, yesnokeys = [1 2]; end
    if iscell(in), in = char(in); end

    % | read data
    % | ========================================================================
    d = load(in);
    b.subjectID = d.subjectID;
    if ismember({'result'},fieldnames(d))
        data        = d.result.trialSeeker;
        blockwise   = d.result.blockSeeker;
        qidx        = blockwise(:, end);
        questions   = regexprep(d.result.preblockcues(qidx), 'Is the person ', '');
    else
        data        = d.trialSeeker;
        blockwise   = d.blockSeeker;
        questions   = d.ordered_questions;
    end
    strrm = {'Is the photo ' 'Is it a result of a ' 'Is it a result of ' 'Is it going to result in a ' 'Is the person '};
    for i = 1:length(strrm)
        questions = regexprep(questions, strrm{i}, '');
    end
    questions = regexprep(questions, ' ', '_');
    questions = regexprep(questions, '?', '');
    questions = regexprep(questions, '-', '_');

    % | blockwise accuracy and durations
    % | ========================================================================
    ntrials         = length(data(data(:,1)==1,1));
    data(data(:,8)==yesnokeys(1), 8) = 1;
    data(data(:,8)==yesnokeys(2), 8) = 2;
    data(:,10)      = data(:,4)~=data(:,8); % errors
    data(data(:,8)==0, 7:8) = NaN; % NR to NaN
    blockwise(:,3)  = data(data(:,2)==1, 6);
    blockwise(:,4)  = data(data(:,2)==ntrials, 9) - data(data(:,2)==1, 6);

    % | compute block-wise error counts
    % | ========================================================================
    for i = 1:size(blockwise, 1)
        blockwise(i,5) = sum(data(data(:,1)==i,10));  % all errors
        blockwise(i,6) = sum(data(data(:,1)==i & data(:,4)==2, 10)); % foil errors
    end
    for i = 1:length(unique(data(:,3)))
        cdata = data(data(:,3)==i, [7 10]);
        b.accuracy(i)  = 100*(sum(cdata(:,2)==0)/size(cdata,1));
        b.rt(i)        = nanmean(cdata(:,1));
    end

    % | Blockwise Labels
    % | ========================================================================
    condlabels = {'Why-NS' 'Why-Face' 'Why-Hand' 'How-NS' 'How-Face' 'How-Hand'};
    qcond = condlabels(blockwise(:,2))';
    rt = round(blockwise(:,4)*1000);
    err = blockwise(:,5);
    b.condlabels = strcat(upper(qcond), '-', upper(questions), '-', num2str(rt), 'ms', '-', num2str(err), 'error');
    b.condlabels = regexprep(b.condlabels, ' ', '');
    b.blockwise = blockwise;

    b.varlabels = {'Block' 'Cond' 'Onset' 'Duration' 'Total_Errors' 'Foil_Errors'};
    end
function mfile_showhelp(varargin)
    % MFILE_SHOWHELP
    ST = dbstack('-completenames');
    if isempty(ST), fprintf('\nYou must call this within a function\n\n'); return; end
    eval(sprintf('help %s', ST(2).file));
    end

