function [ds] = getSettings

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% The purpose of this function is the set all the settings and create a data structure that will be used later on.

% We'll store all the data, settings and other info in our datastructure (ds) in a struct so that it can be passed to functions easily and 
% they can use what they need from it.
ds = struct;

%% General
ds.settings.general.procEEG                         = 1; % Whether you want to process EEG or not 0 for no, 1 for yes
ds.settings.general.procET                          = 0; % Whether you want to process ET or not, 0 for no, 1 for yes

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Paths
% First we're going to set the paths, it's expected that there will be a rootpath, within the rootpath there should be a data folder, within the
% data folder each participant should have it's own folder. Data will be saved in the raw folder and preprocessed folders
% General paths
% ds.settings.paths.rootPath                          = 'E:/Birkbeck/';
% ds.settings.paths.rootPath                          = 'E:/Birkbeck/Stimuli/36m KCL
ds.settings.paths.rootPath                          = 'E:/Birkbeck/Gap task/';
[ds.settings.paths.rootPath]                        = checkPathEnd(ds.settings.paths.rootPath);

if ds.settings.general.procEEG
    % EEG Paths
    ds.settings.paths.dataPath                      = strcat(ds.settings.paths.rootPath, 'MFF_files/');
    ds.settings.paths.rawEEGPath                    = strcat(ds.settings.paths.rootPath, '1.1 Raw_EEG/');
    ds.settings.paths.epochedEEGPath                = strcat(ds.settings.paths.rootPath, '2.1 Epoched_EEG/');
    ds.settings.paths.preprocEEGPath                = strcat(ds.settings.paths.rootPath, '3.1 Preprocessed_EEG/');
    ds.settings.paths.concatEEGPath                 = strcat(ds.settings.paths.rootPath, '4.1 Concatenated_EEG/');
    ds.settings.paths.icaEEGPath                    = strcat(ds.settings.paths.rootPath, '5.1 Post_ICA_EEG/');

    pathList = {ds.settings.paths.rawEEGPath; strcat(ds.settings.paths.rawEEGPath, 'No trials found/'); ds.settings.paths.epochedEEGPath; ...
        strcat(ds.settings.paths.epochedEEGPath, 'Auto rejected/'); ds.settings.paths.preprocEEGPath; ds.settings.paths.concatEEGPath; ...
        ds.settings.paths.icaEEGPath};

    % Checks that the above folders have been created and if not creates them for you, so nothing crashes later on.
    checkAndCreateFolders(pathList);
    % Checks that there is a backslash at the end of each path, otherwise the folder structure could get confused.
    for i = 1:length(pathList); checkPathEnd(pathList{i}); end
end

if ds.settings.general.procET
    % ET Paths
    ds.settings.paths.rawETPath                     = strcat(ds.settings.paths.rootPath, '1.2 Raw_ET/');
    ds.settings.paths.epochedETPath                 = strcat(ds.settings.paths.rootPath, '2.2 Epoched_ET/');
    ds.settings.paths.fixationETPath                 = strcat(ds.settings.paths.rootPath, '3.2 Fixations_ET/');
    ds.settings.paths.concatETPath                  = strcat(ds.settings.paths.rootPath, '4.2 Concatenated_ET/');

    pathList = {ds.settings.paths.rawETPath; strcat(ds.settings.paths.rawETPath, 'No trials found/'); ds.settings.paths.epochedETPath; ds.settings.paths.fixationETPath; ...
        ds.settings.paths.concatETPath};

    % Checks that the above folders have been created and if not creates them for you, so nothing crashes later on.
    checkAndCreateFolders(pathList);
    % Checks that there is a backslash at the end of each path, otherwise the folder structure could get confused.
    for i = 1:length(pathList); checkPathEnd(pathList{i}); end
end

if ds.settings.general.procEEG & ds.settings.general.procET
    ds.settings.paths.lookingEEGPath                = strcat(ds.settings.paths.rootPath, '6.1 EEG_Filtered_with_ET/');
    ds.settings.paths.analysedDataPath              = strcat(ds.settings.paths.rootPath, '7.1 Analysed_Data/');

    pathList = {ds.settings.paths.lookingEEGPath; strcat(ds.settings.paths.lookingEEGPath, 'Filt_By_Null/'); ...
        strcat(ds.settings.paths.lookingEEGPath, 'Filt_By_Fix/')};

    % Checks that the above folders have been created and if not creates them for you, so nothing crashes later on.
    checkAndCreateFolders(pathList);
    % Checks that there is a backslash at the end of each path, otherwise the folder structure could get confused.
    for i = 1:length(pathList); checkPathEnd(pathList{i}); end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Events
% If epochByEvents is set to auto then specify which event numbers signal the start and end of trials, these will be used to epoch the data later on.
ds.settings.epochByEvents                           = 'auto'; % Set this to manual if you would rather do it yourself
ds.settings.epochWithDINMarker                      = 0; % Sometimes the markers have "DIN"
ds.settings.onOffsetEventNumbers                    = [[241 242]; [245 246]; [243 244]; [247 248]]; % Start and end of the trial only, these need to be a list of pairs e.g. [[U V]; [W X]; [Y Z]]
% You should name all trial types and this should match the number of event pairs you've put above. If you want repeats you can repeat and name them
% something different.
ds.settings.eventNames                              = {'social4Hz'; 'nonsocial4Hz'; 'social8Hz'; 'nonsocial8Hz'};

ds.settings.maxEventDiscrepency                     = 1; % The maximum discrepencies allowed between trials within a trial type in seconds. This is used as a check when epoching the data.
ds.settings.minTrialLength                          = 10; % Measured in seconds, the minimum trial length, used when epoching the data
ds.settings.maxTrialLength                          = 16; % Measured in seconds, the maximum expected trial length, used when epoching the data.
ds.settings.expectedTrialLength                     = 15; % Measured in seconds, the expected trial length, used when epoching the data.
    
%% EEG preprocessing
% EEG preprocessing settings
if ds.settings.general.procEEG
    ds.settings.eegPreproc.expectedEEGSampleRate    = 500; %1000; % Checked during epoching
    ds.settings.eegPreproc.expectednbChannels       = 129; % Checked during epoching
    ds.settings.eegPreproc.filterOrder              = 6600; % The filter order used for high and low passes
    ds.settings.eegPreproc.highpass                 = 0.5; % Highpass cutoff
    ds.settings.eegPreproc.lowpass                  = 40; % Lowpass cutoff
    ds.settings.eegPreproc.notch                    = 50; % Notch filter Hz
    ds.settings.eegPreproc.noisyChanThreshold       = 0.25; % The threshold as a percentage for the number of noisy channels that can be rejected and interpolated
    ds.settings.eegPreproc.noisySegmentsThreshold   = 0.25; % The threshold as a percentage for the number of noisy segments (in 1 second chunks) that can be too noisy
end

%% ET preprocessing
% Eye tracking preprocessing settings
if ds.settings.general.procET
    ds.settings.et.etSampleRate                     = 120;
    ds.settings.et.opt.xres                         = 1920; % maximum value of horizontal resolution in pixels
    ds.settings.et.opt.yres                         = 1080; % maximum value of vertical resolution in pixels
    ds.settings.et.opt.missingx                     = -ds.settings.et.opt.xres; % missing value for horizontal position in eye-tracking data (example data uses -xres). used throughout functions as signal for data loss
    ds.settings.et.opt.missingy                     = -ds.settings.et.opt.yres; % missing value for vertical position in eye-tracking data (example data uses -yres). used throughout functions as signal for data loss
    ds.settings.et.opt.freq                         = 120; % sampling frequency of data (check that this value matches with values actually obtained from measurement!)
    ds.settings.et.opt.downsampFilter               = 0; % Always 0

    % Variables for the calculation of visual angle
    % These values are used to calculate noise measures (RMS and BCEA) of fixations. The may be left as is, but don't use the noise measures then.
    ds.settings.et.opt.scrSz                        = [50.9174 28.6411]; % screen size in cm
    ds.settings.et.opt.disttoscreen                 = 65; % distance to screen in cm.
end

%% EEG and ET preprocessing
% If preprocessing both
if ds.settings.general.procEEG & ds.settings.general.procET
    % This filter window factor is the factor that divides into both the EEG and ET sampling rate. This is used to search the data by a set window and
    % remove EEG where the infant isn't looking. For example, a filter window factor of 4 with EEG and ET sampling rates of 1000 and 120Hz means that you
    % are dividing each second by 4, 1000/4 = 250 (ms) (and this divides into both sampling frequencies). Increase the filter window factor to increase
    % the resolution. This number MUST divide into both sampling frequencies.
    ds.settings.eegPreproc.etFilterWindow           = 2;

    % Checks that the above divides into each of the sampling rates and throws an exception if not
    if mod(ds.settings.eegPreproc.expectedEEGSampleRate, ds.settings.eegPreproc.etFilterWindow) ~= 0 & mod(ds.settings.et.etSampleRate , ds.settings.eegPreproc.etFilterWindow) ~= 0
        ME = MException('MATLAB:filterFactorError', 'ET filter window factor does not divide into the EEG and/or ET sampling rate');
        throw(ME)
    end
end

end