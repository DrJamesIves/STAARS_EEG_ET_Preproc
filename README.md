# STAARS_EEG_ET_Preproc
Author: James Ives<br />
For: STAARS project
- https://www.staars.org/
<!-- end of the list -->
Emails: james.white1@bbk.ac.uk / james.ernest.ives@gmail.com<br />
Date: November 7, 2024<br />
License: GNU GPL v3.0<br />
## Background
This repository contains MATLAB scripts for preprocessing EEG and ET data originally for the STAARS dataset. For more information on the STAARS project see: https://www.staars.org/</p>
There is an EEG and eyetracking (ET) component, which ends with being able to filter EEG data using ET looking data (either by null data or fixations).</p>
The EEG pipeline includes data conversion, filtering, artifact rejection, trial concatenation, and independent component analysis (ICA). The scripts are designed for infant EEG datasets and include optional modules for infant-specific processing using iMARA.</p>
The ET pipeline scripts handle tasks like calculating fixations, concatenating trial data, and filtering EEG data based on gaps in the eye-tracking data. These tools are particularly useful for ensuring that EEG data corresponding to periods when the infant was not looking (due to eye closures, distractions, etc.) is appropriately handled.</p>
## Prerequisites
- MATLAB (version compatible with EEGLAB)
- EEGLAB and dependencies for pop_eegfiltnew, pop_cleanline, clean_channels, eBridge, eeg_interp, and pop_runica.
- ds structure containing paths and preprocessing settings, including filter parameters, paths for EEG stages, and thresholds for channel noise rejection.
- eBridge: https://psychophysiology.cpmc.columbia.edu/software/eBridge/index.html
- I2MC: https://github.com/royhessels/I2MC
<!-- end of the list -->
## EEG Script Overview
### 1. convertMFFtoEEGLAB(ds)
Purpose: Converts MFF files from the MFF format into EEGLAB-compatible .set format.</p>
Steps:
- Read MFF Files: Converts MFF files from a specified directory into EEGLAB-compatible format.
- Output EEG Dataset: Saves the converted EEG data as .set files in the specified output directory (ds.settings.paths.preprocEEGPath).
<!-- end of the list -->
### 2. preprocEEG(ds)
Purpose: Preprocesses each trial by applying filtering, noise rejection, and artifact handling.</p>
Steps:
- Highpass Filter: Removes low-frequency noise based on ds.settings.eegPreproc.highpass.
- Notch Filter: Filters out specific frequency bands (e.g., 50Hz electrical noise) using ds.settings.eegPreproc.notch.
- Lowpass Filter: Removes high-frequency noise based on ds.settings.eegPreproc.lowpass.
- Robust Average Reference: Temporarily removes noisy channels, computes an average, and removes this average from all channels.
- Channel Interpolation: Detects and interpolates noisy or bridged channels; noisy channels beyond threshold are replaced with NaNs.
- Bad Section Removal: Rejects sections with high noise (e.g., where 70% of channels show artifacts).
- Save Processed Data: Saves the final processed file to ds.settings.paths.preprocEEGPath.
<!-- end of the list -->
### 3. concatEEGTrials(ds)
Purpose: Concatenates trials into a continuous dataset, ideal for ICA and spectral analysis.</p>
Steps:
- Identify Files for Concatenation: Lists preprocessed files and identifies unique participant identifiers.
- Concatenate Trials: Merges individual trials into a continuous dataset for each participant.
- Save Concatenated Data: Outputs concatenated data into ds.settings.paths.concatEEGPath.
<!-- end of the list -->
### 4. eegICA(ds)
Purpose: Runs Independent Component Analysis (ICA) on concatenated EEG data for artifact detection and removal, optionally applying infant-specific iMARA post-processing.</p>
Steps:
- Load Concatenated Data: Loads each participant’s concatenated EEG data.
- Handle NaNs: Zeros out NaNs (for noisy channels marked in preprocEEG) to allow ICA processing.
- Run ICA: Runs EEGLAB’s ICA function to separate EEG data into independent components.
- Post-ICA Processing (Optional): Placeholder for iMARA, specialized for infant EEG data.
- Restore NaNs: Re-inserts NaN values where channels had been zeroed out.
- Save ICA-Processed Data: Saves the final ICA-processed data in ds.settings.paths.icaEEGPath.
<!-- end of the list -->
### 5. masterPreprocMFFFiles(ds)
Purpose: The main entry point to the pipeline. This script orchestrates the entire EEG data preprocessing pipeline by calling the other functions in sequence.</p>
Steps:
- Convert MFF to EEGLAB: Uses convertMFFtoEEGLAB to convert MFF files into the EEGLAB format.
- Preprocess Data: Calls preprocEEG for each converted dataset.
- Concatenate Trials: Uses concatEEGTrials to concatenate trials for each participant.
- Run ICA: Executes eegICA for each concatenated dataset.
- Logging: Provides progress logging to track the pipeline execution.
<!-- end of the list -->
## ET script overview
### 1. preprocET.m
This script loads raw eye-tracking data, filters the x and y positions using median filtering, and identifies fixations using a two-means clustering algorithm (I2MCfunc). The script saves the fixation data, along with the processed eye-tracking data, for later analysis.</p>
Inputs: Eye-tracking data stored as .mat files in a specified folder.</p>
Outputs: Processed eye-tracking data, including fixations, saved in a designated output folder.</p>
### 2. concatETTrials.m
This script concatenates trial-wise eye-tracking data for each participant. It checks whether the concatenation has been done already, and if not, it loads the individual trial files and merges them into a single participant file.</p>
Inputs: Individual trial files of eye-tracking data.</p>
Outputs: A single concatenated file for each participant.</p>
### 3. filterEEGByLookData.m
This also requires that the EEG data has been preprocessed. This script filters EEG data by removing sections where the infant was not looking. It identifies periods of missing eye-tracking data (i.e., periods when the infant's gaze is missing or the eye tracker was unable to record) and zeroes out the corresponding EEG data.</p>
It provides two filtering options:
- By null values: If the eye-tracking data for a specific window contains missing values, the corresponding EEG data is zeroed.
- By fixations: A future option (commented out) to filter based on fixation data.
<!-- end of the list -->
Inputs: EEG and eye-tracking data stored in .mat files.</p>
Outputs: Filtered EEG data, with zeroed-out sections corresponding to periods of missing eye-tracking data.</p>
## Usage
Configure ds Structure: Ensure that the ds structure is properly set up with paths and filter settings.</p>
Set Up the Environment: Ensure the following directories exist:
'''Matlab
    ds.settings.paths.mffDataPath = 'path/to/mff/files/';
    ds.settings.paths.preprocEEGPath = 'path/to/preprocessed/data/';
    ds.settings.paths.concatEEGPath = 'path/to/concatenated/data/';
    ds.settings.paths.icaEEGPath = 'path/to/ica/data/';
    
    ds.settings.paths.epochedETPath: Path to the folder containing the raw eye-tracking files.
    ds.settings.paths.concatETPath: Path to the folder where concatenated eye-tracking files will be saved.
    ds.settings.paths.concatEEGPath: Path to the folder containing the concatenated EEG files.
    ds.settings.paths.lookingEEGPath: Path where filtered EEG files will be saved.
    
    ds.settings.eegPreproc.highpass = 1;  % Example setting
    ds.settings.eegPreproc.lowpass = 40;
    ds.settings.eegPreproc.notch = 50;
    ds.settings.eegPreproc.filterOrder = 2;
    ds.settings.eegPreproc.noisyChanThreshold = 0.3;  % Example threshold
'''
## Run the Main Script:
To execute the entire pipeline, simply run the masterPreprocMFFFiles(ds) script:
'''Matlab
    masterPreprocMFFFiles(ds);
'''
## Troubleshooting
- **Missing Settings in ds:** Ensure all necessary paths and filter settings are defined in ds to avoid runtime errors.
- **NaN Handling:** Scripts handle NaN values by interpolation or zeroing where appropriate. If ICA or interpolation behaves unexpectedly, verify that NaN replacement is correct for downstream analyses.
- **Excessive Noise:** Files with excessive noise are automatically rejected. Check the "Auto rejected" folder for these files.
- **Memory Constraints:** Concatenation and ICA steps can be memory-intensive; consider downsampling if needed.
- **ICA Failure:** If ICA fails on a specific dataset, the script will log the error and move to the next file.
- **EEG filtering using ET failure:** Make sure that the sample rates for EEG and ET data are correctly aligned when performing the filtering.
<!-- end of the list -->
