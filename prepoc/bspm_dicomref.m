function ref = bspm_dicomref(filepat)
% BSPM_DICOMREF
%
% 2020-01-28 JMT Modified for Anita LOI analysis

if nargin==0, mfile_showhelp; return; end

bspm_dir = fileparts(whichdir('bspm_init.m'));
ref_dir = fullfile(bspm_dir, 'imagedata'); 
ref = files(fullfile(ref_dir, 'dicom_refs', filepat)); 
