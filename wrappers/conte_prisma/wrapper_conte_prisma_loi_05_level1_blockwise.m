% 2020-01-31 Mike Tyszka Create wrapper to call Bob's level1 job setup
% - Blockwise and conditionwise Level 1 run separately
% - Level 1 arguments?

% From wrapper_level1_loisocns_blockwise comments:
% COVIDX
%   01 - Duration
%   02 - Errors (Total)
%   03 - Errors (Foils)
covidx = 1;

append2jobname = 'CONTE_LEVEL1_BLOCKWISE';

root_dir = '/Users/jmt/Data/Conte/Anita_Conte_LOI';
study_dir = fullfile(root_dir, 'sourcedata');
code_dir = fullfile(root_dir, 'code');

matlabbatch = wrapper_level1_loisocns_blockwise(covidx, ...
    'basename',    'SOCNS_LOI2', ...
    'behavid',     'sub-CC*socnsloi2*_results.mat', ...
    'epipat',      'ua*socnsloi2*.nii', ...
    'model',       'BLOCKWISE', ...
    'nskip',       4, ...
    'nuisancepat', 'badscan*txt', ...
    'runid',       'EP_task-socnsloi2*bold*', ...
    'studydir',    study_dir, ...
    'subid',       'CC*', ...
    'TR',          0.7, ... % Assume this is in seconds
    'yesnokeys',   [1 2]);

% Save job in code/ directory
jobname = fullfile(code_dir, sprintf('job_pp_%s_%s.mat', strtrim(datestr(now,'mmm_DD_YYYY')), append2jobname));
save(jobname, 'matlabbatch');

% Run job
spm_jobman('initcfg');
spm_jobman('run', matlabbatch);
