% Beta renamer for BLOCKWISE model

% Key directories
root_dir = '/Volumes/Data/jmt/Conte/Anita_Conte_LOI';
src_dir = fullfile(root_dir, 'sourcedata');

% | relevant directories
subj_dirs = files(fullfile(src_dir, 'CC*'));

% Loop over subject list
for sc = 1:length(subj_dirs)
    
    src_subj_dir = subj_dirs{sc};
    analysis_dir = fullfile(src_subj_dir, 'analysis');
    
    betafiles = files(fullfile(analysis_dir, '*BLOCKWISE*', 'beta*nii'))
    
    betanames2 = bspm_beta2name(betafiles);
    ignoreidx1 = find(~cellfun('isempty', regexp(betanames2, '^R\d+')));
    ignoreidx2 = find(~cellfun('isempty', regexp(betanames2, 'constant')));
    ignoreidx = [ignoreidx1; ignoreidx2];
    betafiles(ignoreidx) = [];
    betanames2(ignoreidx) = [];
    [betapaths, betanames1, betaext] = cellfileparts(betafiles);
    
    for i = 1:length(betafiles)
        movefile(betafiles{i}, fullfile(betapaths{i}, sprintf('%s_%s%s', betanames1{i}, betanames2{i}, betaext{i})))
    end

end