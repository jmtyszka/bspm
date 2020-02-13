clc; clear all;

% CC0006/raw/EP_task-socnsloi2_bold_29
subpat = 'CC*';
epipat = 'EP_task*socnsloi2*';
t1pat = 'GR_T1*'
% studydir = '/data2/conte/derivatives/Anita_Conte_LOI/sourcedata'
studydir = '/Users/jmt/Data/Conte/Anita_Conte_LOI/sourcedata'
template = fullfile(studydir, '/_template_/Template_6.nii');

% - unzip if necessary, get epis
% pigz(fullfile(studydir, subpat, 'raw', t1pat, 'u_rc*gz'));
% pigz(fullfile(studydir, subpat, 'raw', epipat, 'ua*gz'));
funcdirs = files(fullfile(studydir, subpat, 'raw', epipat))
flowfields = files(fullfile(studydir, subpat, 'raw', t1pat, 'u_rc*'));

% - 2mm, 6mm Smoothing
voxsize = 2;
fwhm = 6;

if ~isequal(length(flowfields), length(funcdirs)),
    disp('Mismatch between number of flowfields and images!');
    return;
end

% - DO THE NORMING & BADSCAN!
for i = 1:length(funcdirs)
    bspm_dartel_norm_func(files(fullfile(funcdirs{i}, 'ua*nii')), flowfields{i}, template, voxsize, fwhm);
    swimages = files(fullfile(funcdirs{i}, 'swua*nii'));
    bspm_badscan(swimages, 'prefix', 's6w2ua_badscan');
    % bob_rename(swimages, 'replace', {'swua','s6w2ua'})
end