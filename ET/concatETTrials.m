function concatETTrials(ds)

% Author: James Ives | james.white1@bbk.ac.uk / james.ernest.ives@gmail.com
% Date: 7th November 2024
% Released under GNU GPL v3.0: https://www.gnu.org/licenses/gpl-3.0.html
% Open to collaboration—feel free to contact me!

% The purpose of this function is to concatenate the ET trials so that they are the same as the concatenated EEG trials. Similar to the EEG you may
% not want to do this but if not then no worries, just call data from the previous step.

% Find the files and find the unique partiticpant numbers
files = dir(strcat(ds.settings.paths.epochedETPath, '*.mat'));
filenames = vertcat({files.name})';
for i = 1:length(filenames); filenames{i} = filenames{i}(1:end-6); end
filenames = unique(filenames);

% Loop through the filenames, check if we've already done this step and if we have then skip it.
for filename = 1:length(filenames)
    if ~exist(strcat(ds.settings.paths.concatETPath, filenames{filename}, '.mat'), 'file')
        fprintf(strcat('Loading\t', filenames{filename}, '\tfor concatenating ET\n'))
        % Now search for each participant number individually
        toConcat = dir(strcat(ds.settings.paths.epochedETPath, filenames{filename}, '*.mat'));

        concatET = [];

        % For each of the files load the trial and concatenate. There isn't a fancy concatenation function for this one like there is for the EEG, so it's all
        % done manually.
        for filesFound = 1:length(toConcat)
            ET = load(strcat(ds.settings.paths.epochedETPath, toConcat(filesFound).name));

            if isempty(concatET)
                concatET = ET;
            else
                numSamples = size(concatET.etData, 1);
                concatET.etData = vertcat(concatET.etData, ET.etData);

                % Some ET data will have no fixations, this checks to see if this field is empty, if it is we skip it.
                if isfield(ET.etData, 'I2MC')

                    concatET.I2MC.fixations.cutoff = max([concatET.I2MC.fixations.cutoff, ET.I2MC.fixations.cutoff]);
                    concatET.I2MC.fixations.start = [concatET.I2MC.fixations.start ET.I2MC.fixations.start + numSamples];
                    concatET.I2MC.fixations.end = [concatET.I2MC.fixations.end ET.I2MC.fixations.end + numSamples];
                    concatET.I2MC.fixations.startT = [concatET.I2MC.fixations.startT; ET.I2MC.fixations.startT + numSamples];
                    concatET.I2MC.fixations.endT = [concatET.I2MC.fixations.endT; ET.I2MC.fixations.endT + numSamples];
                    concatET.I2MC.fixations.dur = [concatET.I2MC.fixations.dur; ET.I2MC.fixations.dur];
                    concatET.I2MC.fixations.xpos = [concatET.I2MC.fixations.xpos ET.I2MC.fixations.xpos];
                    concatET.I2MC.fixations.ypos = [concatET.I2MC.fixations.ypos ET.I2MC.fixations.ypos];
                    concatET.I2MC.fixations.flankdataloss = [concatET.I2MC.fixations.flankdataloss ET.I2MC.fixations.flankdataloss];
                    concatET.I2MC.fixations.fracinterped = [concatET.I2MC.fixations.fracinterped ET.I2MC.fixations.fracinterped];
                    concatET.I2MC.fixations.RMSxy = [concatET.I2MC.fixations.RMSxy ET.I2MC.fixations.RMSxy];
                    concatET.I2MC.fixations.BCEA = [concatET.I2MC.fixations.BCEA ET.I2MC.fixations.BCEA];
                    concatET.I2MC.fixations.fixRangeX = [concatET.I2MC.fixations.fixRangeX ET.I2MC.fixations.fixRangeX];
                    concatET.I2MC.fixations.fixRangeY = [concatET.I2MC.fixations.fixRangeY ET.I2MC.fixations.fixRangeY];

                    concatET.I2MC.data.time = [concatET.I2MC.data.time; ET.I2MC.data.time + numSamples];
                    concatET.I2MC.data.right.X = [concatET.I2MC.data.right.X; ET.I2MC.data.right.X];
                    concatET.I2MC.data.right.Y = [concatET.I2MC.data.right.Y; ET.I2MC.data.right.Y];
                    concatET.I2MC.data.right.missing = [concatET.I2MC.data.right.missing; ET.I2MC.data.right.missing];
                    concatET.I2MC.data.finalweights = [concatET.I2MC.data.finalweights; ET.I2MC.data.finalweights];
                end
            end
        end

        % Save the concatenated ET data.
        ET = concatET;
        save(strcat(ds.settings.paths.concatETPath, filenames{filename}, '.mat'), 'ET')
    else
        fprintf(strcat('Skipping\t', filenames{filename}, '\t\tconcatenating complete\n'))
    end
end


end
