function eegICA(ds);

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% The purpose of this function is to take in data that has already been preprocessed and try to clean it further by running EEGLAB's ICA function,
% then running iMARA from Ira Marriott-Haresign https://doi.org/10.1016%2Fj.dcn.2021.101024

% Note the iMARA is for infant data only. There is also a MARA, but EEGLAB's iclabel is probably the way to go to automatically remove bad EEG
% components.

% Find files that have been epoched.
files = dir(strcat(ds.settings.paths.concatEEGPath, '*.mat'));

% Loop through all the files found and check if an ICA/iMARA has already been run on them.
for file = 1:length(files)
    if ~exist(strcat(ds.settings.paths.icaEEGPath, files(file).name), 'file')
        fprintf(strcat('Processing: ', files(file).name, '\t for ICA\n'))

        % Load in the file
        load(strcat(files(file).folder, '\', files(file).name), 'EEG');

        %% Find and remove NaN vectors
        % If there are any channels that have been replaced with NaN vectors because they were noisy, remove and store the values for later
        % First note which channels/timepoints have been NaNed out, these will be stored in nanMask
        nanMask = zeros(size(EEG.data));
        % Then create a temp EEG dataset where we can zero out the NaN data.
        tempEEG = EEG;

        % Loop through the channels and zero out the NaN values
        for chan = 1:size(EEG.data, 1)
            nanChan = find(isnan(EEG.data(chan, :)));
            nanMask(chan, nanChan) = 1;
            tempEEG.data(chan, nanChan) = 0;
        end

        clear nanChan

        % Run the ICA
        try
            EEG = pop_runica(tempEEG, 'extended',1,'interupt','off');
        catch
            fprintf(strcat('ICA failed for\t', files(file).name))
        end

        clear tempEEG

        % TO DO CONFIGURE THE iMARA AND RUN IT HERE

        % Replace the nan values
        for chan = 1:size(EEG.data)
            EEG.data(chan, find(nanMask(chan, :) == 1)) = NaN;
        end

        clear nanMask

        % Save the file
        save(strcat(ds.settings.paths.icaEEGPath, files(file).name), "EEG", "ds")
    else
        fprintf(strcat('Skipping:\t', files(file).name, '\t\tICA has already been run\n'))
    end
end

end