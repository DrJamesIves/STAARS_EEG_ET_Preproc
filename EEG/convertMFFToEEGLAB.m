function convertMFFToEEGLAB(ds)

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% This script takes in the ds.settings from masterPreprocMFFFiles.m and uses it to find the .mff files and convert to .mat EEGLAB friendly files. It
% checks whether there is already a .mff file present and if so it skips this file. If you would like to reconvert the file simply delete or move the
% .mat file.

% This is the only stage of the pipeline where things are supposed to go wrong. Here we have data where there are a lot of possibilities to think about
% and we want to make sure the output is always reliable. So, where there are clearly defined outcomes Iive coded in extra bits to make the output 
% uniform but if it doesnst know then it s designed to throw an error and stop the script so you can investigate. From my experience this happens for 
% three reasons: the data is corrupt (maybe from data transfer or maybe just in general), no EEG data/incomplete data (there are many that are only 
% videos for example), no event data (where the data is otherwise complete but it doesnit have any markers) or the data file is too big.
    % For the first three there’s not a lot you can do, you should check your source to make sure the data transfer wasn’t the issue. If it’s not that 
    % then you should just remove this data from the raw files folder.
    % 
    % For the last one, there is another way of importing the data that does it by chunks. It is a pain in the arse, super buggy, which is why it hasn't
    % been coded in to run automatically. But, Itve included the code as a comment in the script in case you want to try it.


% Finds all .mff files in the data path
files = dir(strcat(ds.settings.paths.dataPath, '*.mff'));

% Loops through all the found files
for file = 1:length(files)
    % Checks to see if the file already has a .mat counterpart and skips it if it has.
    if ~exist(strcat(ds.settings.paths.rawEEGPath, files(file).name(1:end-4), '.mat')) & ~exist(strcat(ds.settings.paths.rawEEGPath, 'No trials found\', files(file).name(1:end-4), '.mat'))
        fprintf(strcat('Processing: ', files(file).name, '\n'))
        noSave = 0;
        % Loads the file, this can take a while. For files that are too big (depends on the amount of RAM and HDD available to MATLAB), this catches errors
        % and tries to load them in in much much smaller chunks. This takes even longer, but the converted file is a lot smaller, so there shouldn't be issues
        % after this.
        try
            % EEG = pop_readegimff(strcat(files(file).folder, '\', files(file).name));
            EEG = pop_mffimport(strcat(files(file).folder, '\', files(file).name), 'code');
        catch
            ME = MException('MATLAB:mffConversionError', 'EEG load failed, this is either because the data is corrupted, incomplete or the file is too big.\nFirst check your source and make sure that the file hasnt been corrupted during transfer.\nIf not that then try again by chunking the data.\nThere is code in the convertMFFToEEGLAB.m script to help with this, but it will have to be done manually.\n');
            throw(ME)
        end
        if ~noSave
            fprintf(strcat('Saving ...\n'))
            % Saves the file in the Raw_EEG folder, it tries to do this with the default save settings, and if not (usually because it is too big) then it runs
            % with the version 7.3 encoding, which is for bigger files.
            warning('')
            save(strcat(ds.settings.paths.rawEEGPath, files(file).name(1:end-4), '.mat'), 'EEG');
            [warnMsg, warnId] = lastwarn;
            if ~isempty(warnMsg)
                fprintf(strcat('Saving using v7.3 encoding ...\n'))
                save(strcat(ds.settings.paths.rawEEGPath, files(file).name(1:end-4), '.mat'), 'EEG', '-v7.3');
            end

        end
    else
        fprintf(strcat('Skipping: ', files(file).name, ' conversion from mff to mat, already processed\n'))
    end
end


%% Previous scripts
% This was part of a previous version, with an alternative loading mechanism. On testing it was a lot more buggy than the current version. 
% Keeping in case it becomes useful as an alternative later.

% firstSample is in samples, sampleDuration is in minutes, EEG2 is our container for the EEG data
% sampleIndex = 1; sampleDuration = 5; EEG2 = [];
% while true
%     % When running in chunks we will pull in 5 minute chunks at a time, if that doesn't work we'll try again with smaller chunks
%     fprintf(strcat('Now trying with a chunk size of\t', num2str(round(sampleDuration * 60)), '\tseconds\n'))
%     try
%         EEG2 = pop_readegimff(strcat(files(file).folder, '\', files(file).name), ...
%             ... % This takes the sample index, minuses 1, multiplies by the expected sample rate and adds 1. This should give 1 for the first 5 mins
%             ... % and then move in increments of 5 minutes depending on the sampling rate.
%             'firstsample', round(((sampleIndex -1) * sampleDuration * ds.settings.expectedEEGSampleRate) + 1), ...
%             ... % This takes the sample index and multiples by the sample duration and expected sample rate to give us the end of the chunk.
%             'lastsample' , round(sampleIndex * sampleDuration * ds.settings.expectedEEGSampleRate));
%
%         EEG = [EEG; EEG2];
%         sampleIndex = sampleIndex + 1;
%     catch
%         try
%             if sampleIndex == 1
%                 sampleDuration = sampleDuration * 0.9;
%             else
%             % It's expected that this would crash at the end unless the data fits perfectly into 5 minute chunks. So here we give a firstsample but not
%             % a last sample so it defaults to 'end'. This should wrap up our EEG file and we can move on.
%             EEG2 = pop_readegimff(strcat(files(file).folder, '\', files(file).name), ...
%                 ... % This takes the sample index, minuses 1, multiplies by the expected sample rate and adds 1. This should give 1 for the first 5 mins
%                 ... % and then move in increments of 5 minutes depending on the sampling rate.
%                 'firstsample', round(((sampleIndex -1) * sampleDuration * ds.settings.expectedEEGSampleRate) + 1));
%
%             EEG = [EEG; EEG2]
%             clear EEG2
%             % break
%             end
%         catch
%
%         end
%         noSave = 1;
%         break
%     end
%     if sampleDuration < 0.001
%         fprintf(strcat('Unable to parse mff file for\t', files(file).name, '\n'))
%         noSave = 1;
%         break
%     end
% end
end