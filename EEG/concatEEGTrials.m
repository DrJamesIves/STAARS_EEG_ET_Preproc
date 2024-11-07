function concatEEGTrials(ds)

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% The purpose of this function is to take each of the trials and concatenate them together. This is important if you want to do an ICA or if you have
% doing spectral analyses where you might need more power. You may want to ignore this step if you want to look at trials individually or if you are
% worried about edge effects between the trials.

% Grab a list of files and find the unique participant numbers to concatenate
files = dir(strcat(ds.settings.paths.preprocEEGPath, '*.mat'));
filenames = vertcat({files.name})';
for i = 1:length(filenames); filenames{i} = filenames{i}(1:end-6); end
filenames = unique(filenames);

% Loop through the filenames found
for filename = 1:length(filenames)
    % If the concatenation has already been done then ignore this file.
    if ~exist(strcat(ds.settings.paths.concatEEGPath, filenames{filename}, '.mat'), 'file')
        fprintf(strcat('Loading\t', filenames{filename}, '\t\tfor concatenating EEG\n'))
        % Finds the specific files to be concatenated.
        toConcat = dir(strcat(ds.settings.paths.preprocEEGPath, filenames{filename}, '*.mat'));

        concatEEG = [];

        % For each of the files to be concatenated load the file and merge it into one dataset.
        for filesFound = 1:length(toConcat)
            EEG = load(strcat(ds.settings.paths.preprocEEGPath, toConcat(filesFound).name), 'EEG'); EEG = EEG.EEG;

            if isempty(concatEEG)
                concatEEG = EEG;
            else
                concatEEG = pop_mergeset(concatEEG, EEG);
            end
        end

        % Save the concatenated dataset.
        EEG = concatEEG;
        save(strcat(ds.settings.paths.concatEEGPath, filenames{filename}, '.mat'), 'EEG')

    else
        fprintf(strcat('Skipping\t', filenames{filename}, '\t\tconcatenating complete\n'))
    end
end

end