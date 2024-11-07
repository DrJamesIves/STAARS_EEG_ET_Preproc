function epochET(ds)

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% This function loads in the ET data and epochs it using the same triggers as the EEG data.

%% Find all relevant files
% Finds all the raw ET files
ds.dataInfo.mainBufferFiles = dir(strcat(ds.settings.paths.rawETPath, '*\*\gaze\mainBuffer*.mat'));
ds.dataInfo.eventBufferFiles = dir(strcat(ds.settings.paths.rawETPath, '*\*\gaze\eventBuffer*.mat'));
ds.dataInfo.timeBufferFiles = dir(strcat(ds.settings.paths.rawETPath, '*\*\gaze\timeBuffer*.mat'));

% Checks that they are all have the same number of files, if not there will be misalignment which needs to be fixed now
if length(ds.dataInfo.mainBufferFiles) ~= length(ds.dataInfo.eventBufferFiles) | length(ds.dataInfo.mainBufferFiles) ~= length(ds.dataInfo.timeBufferFiles)
    ME = MException('The number of main, event and time buffer files is unequal. Fix in the folders and rerun the script.');
    throw(ME)
end

% Cycle through the files
for file = 1:length(ds.dataInfo.mainBufferFiles)
    % First check whether this epoching has already been done. This is done by looking for one of each of the trial types, it's assumed that if each trial
    % type has been done then all of the trials have been epoched.
    numCompleted = 0;
    for trialType = 1:length(ds.settings.eventNames)
        if exist(strcat(ds.settings.paths.epochedETPath, ds.dataInfo.mainBufferFiles(file).name(13:19), '_', ds.settings.eventNames{trialType}, '_1.mat'))
            numCompleted = numCompleted + 1;
        end
    end

    if numCompleted ~= length(ds.settings.eventNames)

        %% Load in files
        % Load the main, event and time buffer files
        fprintf(strcat('Loading\t', ds.dataInfo.mainBufferFiles(file).name(1:end-4), '\t\tfor epoching\n'))
        load(strcat(ds.dataInfo.mainBufferFiles(file).folder, '\', ds.dataInfo.mainBufferFiles(file).name));
        load(strcat(ds.dataInfo.eventBufferFiles(file).folder, '\', ds.dataInfo.eventBufferFiles(file).name));
        load(strcat(ds.dataInfo.timeBufferFiles(file).folder, '\', ds.dataInfo.timeBufferFiles(file).name));

        trialTypeCounter = 0;

        % Match event times with the time buffer
        time = double(timeBuffer(:,1));

        events = cell(length(eventBuffer),4);
        for i = 1:length(eventBuffer)
            if iscell(eventBuffer{i, 3})
                events(i, :) = [eventBuffer(i,1) eventBuffer(i,2) eventBuffer{i,3}];
            else
                events(i, :) = [eventBuffer(i,1) eventBuffer(i,2) eventBuffer{i,3}, NaN];
            end
        end

        % Checks to make sure that the fourth column are all number, sometimes events are read in as char
        for i = 1:size(events, 1)
            if ischar(events{i, 4})
                events{i, 4} = str2num(events{i, 4});
            end
        end

        %% Search and epoching
        % Searches for each trial type individually
        for trialType = 1:length(ds.settings.eventNames)

            startIdx = find([events{:,4}] == ds.settings.onOffsetEventNumbers(trialType, 1))';
            endIdx = find([events{:,4}] == ds.settings.onOffsetEventNumbers(trialType, 2))';
            startEvents = events(startIdx, :);
            endEvents = events(endIdx, :);

            if ~isempty(find([endIdx - startIdx] < 0))
                disp('Theres a problem with the events. Crashing..')
                crashMe
            else
                ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType}) = [startIdx endIdx];
            end

            times = zeros(size(ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType}), 1), 2);
            for i = 1:size(times, 1)
                times(i,1) = dsearchn(time, double(startEvents{i,2}));
                times(i,2) = dsearchn(time, double(endEvents{i,2}));
            end
            times(:,3) = times(:,2) - times(:,1);

            % Any trials that are shorter than the minimum trial length are excluded in this loop
            for i = size(times, 1):-1:1
                if times(i,3) < ds.settings.minTrialLength * ds.settings.et.etSampleRate
                    times(i, :) = [];
                    startIdx(i) = []; startEvents(i, :) = [];
                    endIdx(i) = []; endEvents(i,:) = [];
                end
            end

            if ~isempty(times)
                for trial = 1:size(times, 1)
                    etData = mainBuffer(times(trial,1):times(trial, 2), :);
    
                    save(strcat(ds.settings.paths.epochedETPath, ds.dataInfo.mainBufferFiles(file).name(13:19), '_', ds.settings.eventNames{trialType}, '_', num2str(trial), '.mat'), 'ds', 'etData');
                end
            else
                if ~exist(strcat(ds.settings.paths.rawETPath, 'No trials found\'), 'dir')' mkdir(strcat(ds.settings.paths.rawETPath, 'No trials found\')); end
                % If there are no trials print this to the command window
                fprintf(strcat('No trials found for\t', ds.dataInfo.mainBufferFiles(file).name(13:19), '\t-\t', ds.settings.eventNames{trialType}, '\n'))

                % This checks how many trial types have no trials, if it is every trial type being searched for then this file gets moved to the "No trials found"
                % folder, this is so that in future when this pipeline is run it skips this file.
                trialTypeCounter = trialTypeCounter + 1;
                if trialTypeCounter == length(ds.settings.eventNames)
                    splitFilename = split(ds.dataInfo.mainBufferFiles(file).folder, '\');
                    newFilename = join({splitFilename{1:3}, 'No trials found', splitFilename{4:5}}, '\');
                    movefile(ds.dataInfo.mainBufferFiles(file).folder(1:end-5), ...
                        strcat(newFilename{:}, '\'))
                end
            end
        end
    else
        fprintf(strcat('Skipping\t', ds.dataInfo.mainBufferFiles(file).name(13:19), '\t\tepoching complete\n'))
    end
end

end