function preprocEEG(ds)

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% The purpose of this function is to take in the previously epoched data and apply preprocessing to it.
% This pipeline was produced in part by Ira Marriott-Haresign https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8556604/

% Find files that have been epoched.
files = dir(strcat(ds.settings.paths.epochedEEGPath, '*.mat'));

for file = 1:length(files)

    if ~exist(strcat(ds.settings.paths.preprocEEGPath, files(file).name), 'file') & ...
            ~exist(strcat(ds.settings.paths.epochedEEGPath, 'Auto rejected\', files(file).name), 'file')

        fprintf(strcat('Processing: ', files(file).name, '\n'))
        % Setup the data struct for this file and load the data
        dataInfo = struct;
        load(strcat(files(file).folder, '\', files(file).name), 'EEG');

        %% 1. Highpass the EEG
        % This highpasses the EEG signal using the highpass and filter order setting in ds.
        EEG = pop_eegfiltnew(EEG, [], ds.settings.eegPreproc.highpass, ds.settings.eegPreproc.filterOrder, 1, [], 0);

        %% 2. Notch filter the EEG
        % This is used to remove a specific frequency, which usually represents the electrical frequency where the data
        % were recorded.
        EEG = pop_cleanline(EEG, 'bandwidth',2,'chanlist',(1:EEG.nbchan) ,'computepower',1,'linefreqs', ds.settings.eegPreproc.notch,'normSpectrum',0,'p',0.01,'pad',2,'plotfigures',[],'scanforlines',1,'sigtype','Channels','tau',100,'verb',1,'winsize',3,'winstep',3);

        %% 3. Lowpass the EEG
        % This lowpasses the EEG signal using the highpass and filter order setting in ds.
        EEG = pop_eegfiltnew(EEG, [], ds.settings.eegPreproc.lowpass, ds.settings.eegPreproc.filterOrder, 0, [], 0);

        %% 4. Robust average reference
        % First identify and temporarily remove bad channels, compute and average and remove that average from all channels. dataInfo will be stored with the
        % saved data at the end with relevant info.

        % clean_channels doesn't take data with multiple trials, so first we create a copy and feed in one trial at a time. This may mean that some trials
        % have more rejected channels than others, which is why we're keeping this info.

        % This will be used to store the data quality info for later analysis
        [dataInfo.chansRemovedFromRobustAvg, dataInfo.channelsRejectedForNoise, dataInfo.channelsRejectedForBridging, dataInfo.rejectedSections] = deal([]);

        % Identify noisy channels
        try
            [EEGOUT, removedChans] = clean_channels(EEG);
        catch
            % If there are too many noisy channels it will crash, this just moves that file to the auto reject folder and moves to the next iteration of the loop.
            movefile(strcat(files(file).folder, '\', files(file).name), strcat(files(file).folder, '\Auto rejected\', files(file).name))
            continue
        end

        % Average the clean channels and remove the average from all channels
        EEG.data = EEG.data-mean(EEGOUT.data,1);
        % Clear EEGOUT variable we no longer need and store the number of channels removed from the robust average for later
        clear EEGOUT
        dataInfo.chansRemovedFromRobustAvg = [dataInfo.chansRemovedFromRobustAvg, removedChans];


        %% 5. Check for bad channels, bridging and interpolate
        % Use a slightly narrower check to identify bad channels that are either noisy or bridged.
        
        try
            [~,chans2interp] = clean_channels(EEG,0.7,4,[],[],[],[]); noisyChans = find(chans2interp==1);
        catch
            % If there are too many noisy channels it will crash, this just moves that file to the auto reject folder and moves to the next iteration of the loop.
            movefile(strcat(files(file).folder, '\', files(file).name), strcat(files(file).folder, '\Auto rejected\', files(file).name))
            continue
        end
        
        dataInfo.channelsRejectedForNoise = [dataInfo.channelsRejectedForNoise, chans2interp]; % Store these electrodes
        
        
        % eBridge to checked for bridged channels without bothering to check for bridging from noisy channels
        [EB ED] = eBridge(EEG, {EEG.chanlocs(noisyChans).labels}, 'EpLength', 250);
        
        % Find the bridged channels
        y = zeros(1, EEG.nbchan);
        for chan = 1:size(EB.Bridged.Labels, 2)
            x = strcmp({EB.Bridged.Labels{chan}},{EEG.chanlocs(:).labels}); y = y + x;
        end
        bridgedChans = find(y==1);
        dataInfo.channelsRejectedForBridging.EB = EB; % Store electrode bridge data
        dataInfo.channelsRejectedForBridging.ED = ED; % Store general bridging info
        
        toReject = [noisyChans; bridgedChans'];
        
        % Reject noisy and bridged channels. If there are less channels to interpolate than the rejection threshold, then interpolate them to replace them.
        % If there are more than the threshold of rejected channels then just reject those channels and replace them with NaNs (this keeps the structure
        % of the channels, which is important for spatial analyses later on).
        if length(toReject) > EEG.nbchan * ds.settings.eegPreproc.noisyChanThreshold
            nanVector = nan(1, EEG.pnts);
            for r = 1:length(toReject)
                EEG.data(toReject(r), :) = nanVector;
            end
        else
            % This interpolates channels using nearest neighbours.
            EEG = eeg_interp(EEG, toReject, 'spherical');
        end

        %% 6. Remove bad sections of continuous data
        % If 70% of channels are bad get rid of data
        [signal,mask]=clean_windows(EEG,0.7);
        % Get column index of bad data segments and mark as 0 within EEG data
        [~,indx]=find(mask==0);EEG.data(:,indx)=0;
        dataInfo.rejectedSections = [dataInfo.rejectedSections; {mask'}];

        % EEG2 = EEG;
        % for i = 1:size(EEG.data, 3)
        %     % Create the new trial by trial dataset
        %     EEG2.data = EEG.data(:, :, i);
        %     EEG2.trials = 1;
        %
        %     % Identify noisy channels
        %     [EEGOUT, removedChans] = clean_channels(EEG2);
        %     % Average the clean channels and remove the average from all channels
        %     EEG2.data = EEG2.data-mean(EEGOUT.data,1);
        %     % Clear EEGOUT variable we no longer need and store the number of channels removed from the robust average for later
        %     clear EEGOUT
        %     dataInfo.chansRemovedFromRobustAvg = [dataInfo.chansRemovedFromRobustAvg, removedChans];
        %
        %     %% 5. Check for bad channels, bridging and interpolate
        %     % Use a slightly narrower check to identify bad channels that are either noisy or bridged.
        %     [~,chans2interp] = clean_channels(EEG2,0.7,4,[],[],[],[]); noisyChans = find(chans2interp==1);
        %     dataInfo.channelsRejectedForNoise = [dataInfo.channelsRejectedForNoise, chans2interp]; % Store these electrodes
        %
        %     % eBridge to checked for bridged channels without bothering to check for bridging from noisy channels
        %     [EB ED] = eBridge(EEG2, {EEG2.chanlocs(noisyChans).labels}, 'EpLength', 250);
        %     % Find the bridged channels
        %     y = zeros(1, EEG.nbchan);
        %     for chan = 1:size(EB.Bridged.Labels, 2)
        %         x = strcmp({EB.Bridged.Labels{chan}},{EEG.chanlocs(:).labels}); y = y + x;
        %     end
        %     bridgedChans = find(y==1);
        %     dataInfo.channelsRejectedForBridging.(strcat('trial', num2str(i))).EB = EB; % Store electrode bridge data
        %     dataInfo.channelsRejectedForBridging.(strcat('trial', num2str(i))).ED = ED; % Store general bridging info
        %
        %     toReject = [noisyChans; bridgedChans'];
        %
        %     % Reject noisy and bridged channels. If there are less channels to interpolate than the rejection threshold, then interpolate them to replace them.
        %     % If there are more than the threshold of rejected channels then just reject those channels and replace them with NaNs (this keeps the structure
        %     % of the channels, which is important for spatial analyses later on).
        %     if length(toReject) > EEG2.nbchan * ds.settings.eegPreproc.noisyChanThreshold
        %         nanVector = nan(1, EEG2.pnts);
        %         for r = 1:length(toReject)
        %             EEG2.data(toReject(r), :) = nanVector;
        %         end
        %     else
        %         % This interpolates channels using nearest neighbours.
        %         EEG2 = eeg_interp(EEG2, toReject, 'spherical');
        %     end
        %
        %     %% 6. Remove bad sections of continuous data
        %     % If 70% of channels are bad get rid of data
        %     [signal,mask]=clean_windows(EEG2,0.7);
        %     % Get column index of bad data segments and mark as 0 within EEG data
        %     [~,indx]=find(mask==0);EEG2.data(:,indx)=0;
        %     dataInfo.rejectedSections = [dataInfo.rejectedSections; {mask'}];
        %
        %     EEG.data(:, :, i) = EEG2.data;
        % end
        % Clear these as they won't be needed again
        clear bridgedChans chan chans2interp EB ED i indx mask nanVector noisyChans removedChans r signal toReject x y

        % Reshape the data to concatenate trials for the ICA
        % EEG2 = EEG;
        % EEG2.times = reshape(EEG.times', [1, size(EEG.times, 1) * size(EEG.times, 2)]);
        % EEG2.data = reshape(EEG.data, [size(EEG.data,1), size(EEG.data, 2) * size(EEG.data, 3)]);
        % EEG2.pnts = size(EEG2.data, 2);
        % EEG2.trials = 1;

        % Run the ICA, that can take a while depending on the size of your data
        % EEG2 = pop_runica(EEG2, 'extended',1,'interupt','off');
        %
        % disp('TODO CONCATENATE DATA, RUN ICA, RUN iMARA, SPLIT DATA, SAVE')

        % Save the data
        fprintf(strcat('Saving ...\n'))
        save(strcat(ds.settings.paths.preprocEEGPath, files(file).name(1:end-4), '.mat'), 'EEG', 'dataInfo')
    else
        fprintf(strcat('Skipping:\t', files(file).name, '\t\tEEG preprocessing, already processed\n'))
    end
end


end