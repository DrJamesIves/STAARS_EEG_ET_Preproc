function filterEEGByLookData(ds)

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% This script identifies gaps in eye tracking data (e.g. due to the child not looking) and removes the corresponding time from the EEG. It uses a 
% specified time window to assess if the infant wasn’t looking during the majority of that time. Choose the window based on your research needs and 
% the precision required. For high precision, set the window to the smallest common factor of the EEG and ET sample rates. For larger gaps, adjust the 
% window size based on the fixation of interest. Ensure the window divides both sample rates evenly (e.g., with a 1000Hz EEG and 120Hz ET, use a 
% factor of 40).

% There are two versions of the scripts below, one filters by null values of a specific length, the other uses the I2MC fixations to filter data.

% Get the ET and EEG files
etFiles = dir(strcat(ds.settings.paths.concatETPath, '*.mat')); etFiles = {etFiles(:).name}';
eegFiles = dir(strcat(ds.settings.paths.concatEEGPath, '*.mat')); eegFiles = {eegFiles(:).name}';

% Checks to find participants that have both ET and EEG data, ignores all others. There's a quirk that means it doesn't matter which way round this is
% done they always come up with the same list.
for i = length(etFiles):-1:1
    if ~ismember(etFiles{i}, eegFiles)
        etFiles(i, :) = [];
    end
end

files = etFiles;
clear eegFiles etFiles

%% Filter by null values
% Loop through the files found, check if this has already been done and if not continues.
for file = 1:length(files)
    if ~exist(strcat(ds.settings.paths.lookingEEGPath, files{file}, '.mat'), 'file')
        fprintf(strcat('Loading\t\t', files{file}, '\tto filter EEG by ET data\n'))

        numSegsZeroed = 0;

        % Load the data
        EEG = load(strcat(ds.settings.paths.concatEEGPath, files{file})); EEG = EEG.EEG;
        ET = load(strcat(ds.settings.paths.concatETPath, files{file})); ET = ET.ET;

        % Calculate the window of data that we want to look at based on the ET sampling rate
        window = ds.settings.et.etSampleRate/ds.settings.eegPreproc.etFilterWindow;
        % Calculates the respective size of the gap we want to put into the EEG data
        zeroWindow = zeros(size(EEG.data, 1), EEG.srate/ds.settings.eegPreproc.etFilterWindow);

        % Takes the data and goes in steps of the window that was just created with no overlap
        for win = 1:window:size(ET.etData, 1)
            % This is just in case we reach the end of the data set and there isn't a perfect window sized amount of data left. In this scenario it just takes the
            % data until the end.
            if win + window > size(ET.etData, 1)
                % Finds the points where there is null data in the x and y coordinate column
                sumMissingETData = size(find(ET.etData(win:end, 20) == -1 & ET.etData(win:end, 21) == -1), 1);
                % Finds the remainder slice of data, divides it by 2 and rounds it, then sees if there is a majority of missing data. If so it zeroes out that section
                % in the EEG data.
                if sumMissingETData > (size(ET.etData, 1) - win)/2
                    EEG.data(:, round(((win-1)/ds.settings.et.etSampleRate)*EEG.srate)+1:end) = zeros(size(EEG.data, 1), size(EEG.data, 2) - (((win-1)/ds.settings.et.etSampleRate)*EEG.srate));
                    numSegsZeroed = numSegsZeroed + 1;
                end
            else
                % Does the same as the above but for regular segments of data
                sumMissingETData = size(find(ET.etData(win:win-1+window, 20) == -1 & ET.etData(win:win-1+window, 21) == -1), 1);
                if sumMissingETData > window / 2
                    EEG.data(:, round(((win-1)/ds.settings.et.etSampleRate)*EEG.srate)+1:round(((win-1+window)/ds.settings.et.etSampleRate)*EEG.srate)) = zeroWindow;
                    numSegsZeroed = numSegsZeroed + 1;
                end
            end
        end

        save(strcat(ds.settings.paths.lookingEEGPath, 'Filt_By_Null\', files{file}), 'ds', 'EEG', 'ET', 'numSegsZeroed');
    else
        fprintf(strcat('Skipping\t', files{file}, '\t\tfiltering by null ET complete\n'))
    end
    % 
    % save(strcat(ds.settings.paths.lookingEEGPath, 'Filt_By_Null\', files{file}), 'EEG', 'ET', 'samplesZeroed');

    %% Filter by fixations
    % for file = 1:length(files)
    % 
    %     samplesZeroed = 0;
    % 
    %     EEG = load(strcat(ds.settings.paths.concatEEGPath, files{file})); EEG = EEG.EEG;
    %     ET = load(strcat(ds.settings.paths.concatETPath, files{file})); ET = ET.ET;
    % 
    %     win = ds.settings.et.etSampleRate/10;
    %     zeroWindow = zeros(size(EEG.data, 1), EEG.srate/10);
    % 
    %     for win = 1:win:size(ET.etData, 1)
    %         if win + win > size(ET.etData, 1)
    %             sumMissingETData = size(find(ET.etData(win:end, 20) == -1 & ET.etData(win:end, 21) == -1), 1);
    %             if sumMissingETData > size(ET.etData, 1) - win + 1
    %                 EEG.data(:, round(((win-1)/ds.settings.et.etSampleRate)*EEG.srate)+1:end) = zeros(size(EEG.data, 1), size(ET.etData, 1) - win + 1);
    %                 samplesZeroed = samplesZeroed + 1;
    %             end
    %         else
    % 
    %             sumMissingETData = size(find(ET.etData(win:win-1+win, 20) == -1 & ET.etData(win:win-1+win, 21) == -1), 1);
    %             if sumMissingETData > win / 2
    %                 EEG.data(:, round(((win-1)/ds.settings.et.etSampleRate)*EEG.srate)+1:round(((win-1+win)/ds.settings.et.etSampleRate)*EEG.srate)) = zeroWindow;
    %                 samplesZeroed = samplesZeroed + 1;
    %             end
    %         end
    %     end
    % end
end

end