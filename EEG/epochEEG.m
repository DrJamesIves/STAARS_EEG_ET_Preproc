function epochEEG(ds)

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% This function loads raw EEG data, locates onset/offset event codes from ds.settings, epochs the data by trial type, and saves each type (e.g., social, 
% non-social) as separate files in the epoched_EEG folder. It handles cases where recordings start late or end early if within the min-max trial length.

% It flags trials that are too long/short, potentially due to cut-off, skipped, or incorrect events. Trials already epoched are skipped by checking the 
% number of saved epochs against the expected count, though files with fewer trials than expected won’t be skipped.

% Finds all the raw EEG files
ds.dataInfo.files = dir(strcat(ds.settings.paths.rawEEGPath, '*.mat'));

% Event prefix
if ds.settings.epochWithDINMarker
    prefix = 'DIN';
else
    prefix = '';
end

% Loops through all the raw EEG files
for file = 1:length(ds.dataInfo.files)

    % First check whether this epoching has already been done by checking whether the first of each of the trial types has been epoched. We will assume
    % that it has been done successfully if all trial types are present.
    numCompleted = 0;
    for trialType = 1:length(ds.settings.eventNames)
        if exist(strcat(ds.settings.paths.epochedEEGPath, ds.dataInfo.files(file).name(1:end-4), '_', ds.settings.eventNames{trialType}, '_1.mat'))
            numCompleted = numCompleted + 1;
        end
    end

    % If there are one or more trials that are missing then attempt to epoch the data
    if numCompleted ~= length(ds.settings.eventNames)

        fprintf(strcat('Loading\t\t', ds.dataInfo.files(file).name, '\t\tfor epoching\n'))
        % Loads EEG file
        load(strcat(ds.dataInfo.files(file).folder, '\', ds.dataInfo.files(file).name));
        % We'll create a copy so we can use that later
        EEG2 = EEG;

        % This counter is used to count the number of trial types that have no trials. Later on, if it determines that there are no trials at all it moves
        % this file to a "No trials found" folder.
        trialTypeCounter = 0;

        %% Checks
        % Checks that the EEG sampling rate is the same as expected (specified in the master script)
        if EEG.srate ~= ds.settings.eegPreproc.expectedEEGSampleRate
            fprintf(strcat('Sampling rate was different from expected, resampling to correct rate'))
            if EEG.srate > ds.settings.eegPreproc.expectedEEGSampleRate
                EEG.data = resample(EEG.data, EEG.srate, ds.settings.eegPreproc.expectedEEGSampleRate);
            elseif EEG.srate < ds.settings.eegPreproc.expectedEEGSampleRate
                ME = MException('MATLAB:samplingError', 'Sampling rate is lower than expected, you could inpterpolate this data with interp1, but this script wont do that automatically.');
                throw(ME)
            end
        end

        if EEG.nbchan ~= ds.settings.eegPreproc.expectednbChannels
            ME = MException('MATLAB:channelError', 'Number of channels is not as expected.');
            throw(ME)
        end

        %% Search and epoching
        % Searches for each trial type individually
        for trialType = 1:length(ds.settings.eventNames)
            % Creates an onset/offset even space for each of the trial types. This will be filled later.
            ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType}) = [];
            ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType}) = [];

            % Finds all the onset and offset events for each trial type and stores in the dynamic struct.
            for i = 1:length(EEG2.event)
                event = replace(EEG2.event(i).type, ' ', '');
                if strcmp(event, strcat(prefix, num2str(ds.settings.onOffsetEventNumbers(trialType, 1)))) | strcmp(EEG2.event(i).type, strcat('D', num2str(ds.settings.onOffsetEventNumbers(trialType, 1))))
                    % Finds the onset/offset indices and latencies and storet them in dataInfo. Note that the mff file has incredibly precise latencies that aren't super
                    % useful to us when they are more specific than the sampling rate of the EEG setup. So when the latencies are taken they are rounded.
                    ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType}) = [ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType}); i, 0];
                    ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType}) = [ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType}); round(EEG2.event(i).latency), 0, 0];
                elseif strcmp(event, strcat(prefix, num2str(ds.settings.onOffsetEventNumbers(trialType, 2)))) | strcmp(EEG2.event(i).type, strcat('D', num2str(ds.settings.onOffsetEventNumbers(trialType, 2))))
                    % Checks to see if the latencies for this trial type are empty, which indicates that there wasn't a starting event found so it isn't a full trial.
                    % It also checks that there isn't already another value already in the end spot, this indicates that the end trigger has been sent twice. We want to
                    % ignore the second one.
                    if ~isempty(ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})) & ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(end, 2) == 0
                        ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(end, 2) = i;
                        ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(end,2) = round(EEG2.event(i).latency);
                        % Gives us the duration, which will be used later
                        ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(end,3) = ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(end,2) - ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(end,1);
                    else
                        % If there is an end event before any start events it is likely that this means the recording was started after the screen task started, so this
                        % checks whether this event is close to the start of the recording and if it is and it meets the minimum trial length then the first data point is
                        % taken as the starting event. If it doesn't then there's not much point taking it anyway.
                        % if EEG2.event(i).latency < ds.settings.expectedTrialLength * EEG.srate & EEG2.event(i).latency > ds.settings.minTrialLength * EEG.srate
                        %     ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(end, 2) = 0;
                        %     ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(end,2) = 1;
                        %     % Gives us the duration, which will be used later
                        %     ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(end,3) = ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(end,2) - ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(end,1);
                        % end
                    end
                end
            end

            % Looks for orphaned trials, ones with a start and not an end. This can occur if the wrong end trigger is sent. So this takes those, and tries to find
            % any end trigger. It then checks to see if this corresponds to within 10% of the expected trial length. If so it assumes that this is correct and
            % creates a new trial
            % missedEndEvents = find([ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(:, 2)] == 0);
            % % If missing end events are found
            % if missedEndEvents > 0
            %     % Cycle through the end events
            %     for i = 1:length(missedEndEvents)
            %         % Grab the corresponding start event and latency
            %         missedOnsetEvent = ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(missedEndEvents(i), 1);
            %         missedOnsetLatency = ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i), 1);
            % 
            %         % Get a list of codes from the onset event until the end, find the next end event and see if that matches
            %         % eventCodes = string(vertcat(EEG2.event(missedOnsetEvent:end).code));
            %         % endEventIndex = find(strcmp(string(strcat('DIN', num2str(ds.settings.onOffsetEventNumbers(:, 2)))), eventCodes), 1);
            % 
            %         % Cycle through the events starting from the missed start event
            %         for j = missedOnsetEvent:length(EEG2.event)
            %             % This takes the event type readout and compares it to each of the end event and returns true if it finds any end event.
            %             if ~isempty(find(strcmp(EEG2.event(j).type, string(strcat('DIN', num2str(ds.settings.onOffsetEventNumbers(:, 2))))))) | ~isempty(find(strcmp(EEG2.event(j).type, string(strcat('D', num2str(ds.settings.onOffsetEventNumbers(:, 2)))))))
            %                 % This checks if that end event is within 10% either side of the expected trial length and if it is it takes  this event as the end event
            %                 if (missedOnsetLatency + (ds.settings.expectedTrialLength * EEG.srate * 0.9)) < round(EEG2.event(j).latency) < (missedOnsetLatency + (ds.settings.expectedTrialLength * EEG.srate * 1.1))
            %                     ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(missedEndEvents(i), 2) = j;
            %                     ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i),2) = round(EEG2.event(j).latency);
            %                     % Gives us the duration, which will be used later
            %                     ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i),3) = ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i),2) - ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i),1);
            %                 end
            %                 % If we get to the end of the data and there hasn't been an end event this suggests that the recording was stopped before the end event could be sent.
            %                 % So in this case take the last datapoint as the the end event and see if this is long enough
            %             elseif j == length(EEG2.event)
            %                 if (missedOnsetLatency + (ds.settings.expectedTrialLength * EEG.srate * 0.9)) < round(EEG2.pnts/EEG2.srate) < (missedOnsetLatency + (ds.settings.expectedTrialLength * EEG.srate * 1.1))
            %                     ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(missedEndEvents(i), 2) = j;
            %                     ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i),2) = round(EEG2.event(j).latency);
            %                     % Gives us the duration, which will be used later
            %                     ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i),3) = ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i),2) - ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(missedEndEvents(i),1);
            %                 end
            %             end
            %         end
            %     end
            % end

            % Any trials that are shorter than the minimum trial length are excluded in this loop
            for i = size(ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType}), 1):-1:1
                if ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(i,3) < ds.settings.minTrialLength * EEG.srate
                    fprintf(strcat('Warning: a trial in\t', ds.dataInfo.files(file).name, '\t', ds.settings.eventNames{trialType}, ' is under the minimum epoching length\n'))
                    ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(i,:) = [];
                    ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(i,:) = [];
                elseif ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(i, 3) > ds.settings.maxTrialLength * EEG.srate
                    fprintf(strcat('Warning: a trial in\t', ds.dataInfo.files(file).name, '\t', ds.settings.eventNames{trialType}, ' is over the maximum epoching length\n'))
                    ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(i,:) = [];
                    ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(i,:) = [];
                end
            end

            % Does a check to make sure that ther eare some trials found, if not then it skips the next section.
            if ~isempty(ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType}))

                for trial = 1:size(ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType}), 1)
                    % We're going to reset the EEG variable so we can fill it with epochs to save
                    EEG.setname = ds.settings.eventNames{trialType};
                    [EEG.data, EEG.times, EEG.pnts, EEG.event] = deal([]);
                    EEG.trials = 0;
                    % minDur = round(min(ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(:,3))); % Gives the minimum duration
                    % maxDur = round(max(ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(:,3))); % Gives the maximum duration
                    %
                    % % This checks the range of durations found, and if there is more than a 1 second discrepency then it flags it to the user
                    % if maxDur-minDur > ds.settings.maxEventDiscrepency * EEG.srate;
                    %     resp = input(fprintf(strcat('Potential error - trial duration range is\t', num2str(maxDur-minDur), ' seconds which is above the expected limit. Hit enter to confirm this is okay or i to crash the script and inspect (if "Pause with errors" is on) -\t')), 's');
                    %     if resp == 'i'
                    %         hh
                    %     end
                    % % elseif minDur < ds.settings.minTrialLength * EEG.srate
                    % %     resp = input(fprintf(strcat('Potential error - trial duration is less than\t', num2str(ds.settings.minTrialLength), ' seconds. Hit enter to confirm this is okay or i to crash the script and inspect (if "Pause with errors" is on) -\t')), 's');
                    % %     if resp == 'i'
                    % %         hh
                    % %     end
                    % end

                    % Next now that we have found the indices for these events we'll go through and do the epoching.
                    % for i = 1:size(ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType}), 1)
                    % We don't need to do this but it makes it much easier to read. We first set the epoch onset and offset, which we'll use to chunk the data later.
                    % The onset, offset, minDur and maxDur are rounded because the latencies are incredibly precise but we need these to be in samples so they need to be
                    % whole numbers.
                    onset = round(ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(trial, 1));
                    offset = round(ds.dataInfo.onOffsetLatencies.(ds.settings.eventNames{trialType})(trial, 2));
                    EEG.data = EEG2.data(:, onset:offset);
                    EEG.times = [EEG.times; EEG2.times(1, onset:offset)];

                    % With the events we want the information to be relative to the new epochs rather than to the whole original file, this section takes in the original
                    % events, stores the first row of information and removes that from every subsequent row.

                    % For the first event in the row, store its values
                    first_latency = round(EEG2.event(ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(trial, 1)).latency);
                    first_init_index = EEG2.event(ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(trial, 1)).description;
                    % first_init_time = EEG2.event(ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(i, 1)).init_time;

                    % Create a temp variable we can edit
                    temp = EEG2.event(ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(trial, 1):ds.dataInfo.onOffsetEvents.(ds.settings.eventNames{trialType})(trial, 2));

                    % Modifies all subsequent rows
                    for j = 1:length(temp)
                        temp(j).latency = round(temp(j).latency) - first_latency + 1;
                        temp(j).description = num2str(str2num(temp(j).description) - str2num(first_init_index) + 1);
                        % temp(j).init_time = temp(j).init_time - first_init_time + 0.001;
                    end

                    EEG.event = [EEG.event, temp];
                    clear temp
                    % end

                    EEG.trials = 1;
                    EEG.pnts = offset - onset + 1;
                    EEG.xmax = max(EEG.data, [], 'all');
                    EEG.xmin = min(EEG.data, [], 'all');

                    % Example of how you could epoch the data if you want to instead epoch specific times relative to events
                    % EEG3 = pop_epoch(EEG, { 'DIN241' 'DIN242' }, [-0.1 0.5], 'newname', 'Social4Hz', 'epochinfo', 'yes');

                    % Save the data
                    save(strcat(ds.settings.paths.epochedEEGPath, ds.dataInfo.files(file).name(1:end-4), '_', ds.settings.eventNames{trialType}, '_', num2str(trial), '.mat'), 'ds', 'EEG');
                end
            else
                % If there are no trials print this to the command window
                fprintf(strcat('No trials found for\t', ds.dataInfo.files(file).name, '\t-\t', ds.settings.eventNames{trialType}, '\n'))

                % This checks how many trial types have no trials, if it is every trial type being searched for then this file gets moved to the "No trials found"
                % folder, this is so that in future when this pipeline is run it skips this file.
                trialTypeCounter = trialTypeCounter + 1;
                if trialTypeCounter == length(ds.settings.eventNames)
                    movefile(strcat(ds.settings.paths.rawEEGPath, ds.dataInfo.files(file).name), strcat(ds.settings.paths.rawEEGPath, 'No trials found\', ds.dataInfo.files(file).name))
                end
            end
        end

        % Clearing this info so we don't epoch based on previous files
        ds.dataInfo.onOffsetEvents = [];
        ds.dataInfo.onOffsetLatencies = [];
    else
        fprintf(strcat('Skipping\t', ds.dataInfo.files(file).name, '\t\tepoching complete\n'))
    end
end
end