% Convert DICOM series into Bob's LOI analysis structure
% - subject folders in sourcedata/
% - new raw/, behav/ and analysis/ folders created in each subject folder
% - DICOM series converted with .nii with .mat sidecars
%
% AUTHOR : Mike Tyszka
% PLACE  : Caltech Brain Imaging Center
% DATES  : 2020-01-23 JMT From Bob's documentation

root_dir = '/Volumes/Data/jmt/Conte/Anita_Conte_LOI';
src_dir = fullfile(root_dir, 'sourcedata');

% Output raw directory
raw_dir = fullfile(root_dir, 'raw');

% Load the subject list from CSV
C = table2cell(readtable('subject_list.csv'));

% Loop over subject list
for sc = 1:length(C)
    
    src_subj_dir = fullfile(src_dir, C{sc,1});
    
    fprintf('\n');
    fprintf('Converting subject %s\n', C{sc, 1});
    
    % Check for prior conversion
    raw_dir = fullfile(src_subj_dir, 'raw');
    conv_needed = false;
    if isfolder(raw_dir)
        raw_dlist = dir(raw_dir);
        if length(raw_dlist) < 3
            conv_needed = true;
        else
            fprintf('*  Prior conversion detected - skipping\n');
        end
    else
        conv_needed = true;
    end
    
    if conv_needed
        bspm_convert_dcm(src_subj_dir, 'outputdir', raw_dir);
    end
    
end