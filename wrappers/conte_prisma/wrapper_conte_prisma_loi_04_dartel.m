% DARTEL segmentation
% - parallelize over subjects
%
% 2020-01-31 Mike Tyszka Create wrapper to call Bob's Dartel wrappers

append2jobname = 'CONTE_DARTEL';

root_dir = '/Users/jmt/Data/Conte/Anita_Conte_LOI';
study_dir = fullfile(root_dir, 'sourcedata');
code_dir = fullfile(root_dir, 'code');

% Find subject directories
subj_dirs = files(fullfile(study_dir, 'CC*'));

% Build array of subject jobs
n_subj = length(subj_dirs);
job_array = cell(n_subj, 1);
fprintf('Found %d subject directories\n', n_subj);

% Loop over subjects in sourcedata/
for s = 1:n_subj
    
    subj_dir = subj_dirs{s};
    [~, subj_name, ~] = fileparts(subj_dir);
    
    fprintf('Constructing DARTEL job for %s\n', subj_name);
    
    % File pattern for T1w directory
    anatpat = fullfile(subj_dir, 'raw', 'GR_T1w*');

    % Construct and save DARTEL job into array
    job_array{s} = bspm_dartel_create_template(anatpat);
    
end

% Save job array in code/ directory
jobname = fullfile(code_dir, sprintf('job_pp_%s_%s.mat', strtrim(datestr(now,'mmm_DD_YYYY')), append2jobname));
save(jobname, 'job_array');

%
% Distribute job array
%

% Setup parallel pool
if isempty(gcp('nocreate')), parpool; end

% Init SPM job manager
spm_jobman('initcfg');

parfor jc = 1:length(job_array)
    
    spm_jobman('run', job_array{jc});
    
end

% Delete parallel pool
delete(gcp('nocreate'));
