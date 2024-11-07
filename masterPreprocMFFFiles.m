function masterPreprocMFFFiles

% ------------------------------------------------------------------------------------------------------
% Author: James Ives
% Email: james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% 
% This script was written by James Ives and is released under the GNU General Public License v3.0. 
% with foundational support from Ira Marriott-Haresign https://doi.org/10.1016/j.dcn.2021.101024
%
% You are free to redistribute and/or modify this script under the terms of the GNU General Public 
% License as published by the Free Software Foundation, either version 3 of the License, or (at 
% your option) any later version.
% 
% This script is provided "as-is" without any warranty; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more 
% details: https://www.gnu.org/licenses/gpl-3.0.html
% 
% I am happy to collaborate on any projects related to this script. 
% Feel free to contact me at the email addresses provided.
% -----------------------------------------------------------------------------------------------------

% The purpose of this script is to a) load .mff files into an EEGLAB friendly structure, b) auto sync and crop EEG to ET and video streams, c)
% automatically preprocess and save EEG files, d) Use ET and video to detemine whether the infant was looking at the screen and separate these
% segments from the rest.

%% Setup
% 1. You must update the root path (just the folder where everything is stored) and scripts path (where these scripts are stored) below otherwise nothing will run.
% 2. Your .mff data should be in a folder called "MFF_files", which should be within your root path
% 3. You must have eeglab installed https://sccn.ucsd.edu/eeglab/downloadtoolbox.php/
% 4. You must have the MFFMatlabio plugin installed within eeglab. To install after getting eeglab, type eeglab in the command window and the eeglab gui
% will pop up, go to File > Manage EEGLAB extensions. In the top right hand corner search for mffimport and install.
% 5. You need to change the memory settings in matlab so that it has enough bandwidth to load in all the files, your PC should ideally have at least
% 16Gb of RAM. To change the settings Home > Preferences > General > Java Heap Memory > Max this out. See the troubleshooting section for more details.
% 6. Check through the ds.settings and make sure that they match what you want to do, the rest should be taken care of.

%% Recommendations
% This script is best run on a PC/Mac that isn't doing anything else. It uses a lot of the PCs CPU and RAM, especially at the start.
% It would be worth turning on "Pause on Errors" which is in the drop down below the "Play" button
% There is text at the start of each script, so if you are concerned with the way this pipeline is doing something in particular (for example there
% are a lot of warnings of small trials), then there may be extra information that may explain further.

%% Troubleshooting
% There is a trouble shooting guide at the bottom of this script broken down largely by section.

%% Settings
% You shouldn't need to update any of the other sections, all should be controllable through these ds.settings alone. 
% Feel free to change the settings in getSettings.

% Point this towards the scripts folder for these downloaded scripts
addpath(genpath('E:\Birkbeck\Scripts\'))

% We'll store all the data, settings and other info in our datastructure (ds) in a struct so that it can be passed to functions easily and 
% they can use what they need from it.
[ds] = getSettings;

%% EEG
%% Load .mff files and convert to EEGLAB friendly .mat files
% EEGLAB will make preprocessing super easy, so first convert to .mat files and save the raw version in the designated folder
% First open EEGLAB, if you don't have EEGLAB follow the prompts in the command window to install it.
if ds.settings.general.procEEG

    %% Load .mff files and convert to EEGLAB friendly .mat files
    % EEGLAB will make preprocessing super easy, so first convert to .mat files and save the raw version in the designated folder
    % First open EEGLAB, if you don't have EEGLAB follow the prompts in the command window to install it.
    eeglab
    % Converts .mff to EEGLAB .mat files
    convertMFFToEEGLAB(ds);

    %% Auto sync EEG
    % Specify the events to look for above. First the data are epoched, named and saved.
    epochEEG(ds)

    %% Preprocess EEG files
    % Preprocess the data as individual trials
    preprocEEG(ds)

    %% Concatenate the data
    % Concatenate the data
    concatEEGTrials(ds);

    %% Run an ICA and iMARA
    % This isolates known bad components of the data and removes them (e.g. artefacts caused by heart rate, blinking, chewing, movement, bad electrodes
    % etc)
    eegICA(ds);
end

%% Eye tracking
if ds.settings.general.procET
    %% Auto sync ET
    % Specify the events to look for above. First the data are epoched, named and saved.
    epochET(ds)
    
    %% Process infant looking behaviour 
    preprocET(ds)
    
    %% Concatenate the data
    % Concatenate the data
    concatETTrials(ds);
end

if ds.settings.general.procEEG & ds.settings.general.procET
    %% Zero out EEG where infant isn't looking
    filterEEGByLookData(ds)
end

%% Troubleshooting guide

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% convertMFFToEEGLAB

% "OutOfMemory" Java memory error
% Especially in this script the file can be really big because it's sorting through the entire mff. In fact one of the key reasons to switch to a
% .mat EEGLAB format is that it is much more compact. If you repeatedly get this error then it would be worth increasing your Java.Memory.HeapSpace 
% variable, this will give MATLAB more of the computer's RAM to play with, which will impact on other processing but will likely let you load the
% massive files. To do this: go to Home > Preferences > General > Java Heap Memory > Max this out, it can always be changed back later.

% Time zone issue when using mff_import
% For some reason the timezone is recorded, and if it doesn't match between the EEG.events and the newtimezone variable then it crashes. I don't think
% we care about the timezone so within mff_import I have commented out lines 215-217, which otherwise do nothing. 

end