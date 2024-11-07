function preprocET(ds)

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% The purpose of this function is the take in the eye tracking data and calculate fixations. This is because ET data can be quite patchy, with missed
% samples, infants looking away, obstructions to the eyes etc. Plus a sample at a particular location doesn't hold much weight, as it may be a
% fleeting glance or a transition to a new location.

% Finds all the ET files (these should be in a separate folder from the EEG).
files = dir(strcat(ds.settings.paths.epochedETPath, '*.mat'));

% Loops through the files found and checks to see if the fixation data has been done before.
for file = 1:size(files, 1)
    if ~exist(strcat(ds.settings.paths.fixationETPath, files(file).name))
        fprintf(strcat('Loading\t\t', files(file).name(1:end-4), '\t\tfor ET fixation processing\n'))

        % Loads the data
        load(strcat(files(file).folder, '\', files(file).name), 'etData')

        % Converts the data using the x and y resolution in settings
        xData = etData(:,20)*ds.settings.et.opt.xres;
        yData = etData(:,21)*ds.settings.et.opt.yres;

        % Sets the limits of the screen
        xData(xData==-ds.settings.et.opt.xres) = NaN;
        yData(yData==-ds.settings.et.opt.yres) = NaN;

        % Applies a median filtering
        xData = medfilt1(xData);
        yData = medfilt1(yData);

        ds.dataInfo.etData.time = 1:size(etData, 1);
        ds.dataInfo.etData.right.X = medfilt1(xData);
        ds.dataInfo.etData.right.Y = medfilt1(yData);

        % Identification of fixations by 2-means clustering. See script for reference
        I2MC = struct;
        [I2MC.fixations, I2MC.data, I2MC.parameters] = I2MCfunc(ds.dataInfo.etData, ds.settings.et.opt);

        % As long as it finds fixations we save these along with our filtered data and settings
        if ~isempty(I2MC.fixations.dur)
            save(strcat(ds.settings.paths.fixationETPath, files(file).name), 'ds', 'I2MC', 'etData')
        end
    else
        fprintf(strcat('Skipping\t', files(file).name(1:end-4), '\t\tET fixation processing complete\n'))
    end
end

end