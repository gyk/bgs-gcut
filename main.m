%% Prepares video
videoPath = fullfile(CONFIG.HE_PATH, 'S2\Image_Data\Walking_1_(C1).avi');
vReader = VideoReader(videoPath);

%% Trains background model
bgModel = BackgroundModel();
bgModel.train(vReader, 200);

%% Checks background model
StatInspector.visualizeBgStat(bgModel.bgStat);
pause;
StatInspector.visualizeBgEdges(bgModel.bgEdges, true);
pause;
StatInspector.threeSigma(bgModel.bgStat, vReader);

%% Extracts foreground for each video frame
nFrames = getNFrames(vReader);
for i = 1:3:nFrames
	im = vReader.read(i);
	fg = bgModel.subtract(im);
	imshow(fg);
	title(['#', num2str(i)])
	pause;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Test background subtraction in VideoStream
CONFIG.addPaths();
hes = HEUtilities.select(CONFIG.REAL_TE_FILTER);
HEUtilities.extractPoses(hes, CONFIG.REAL_TE_SUFFIX);

i = input(sprintf('Choose a sequence in HumanEva Dataset (1 - %d): ', ...
	numel(hes)));
he = hes(i);
fprintf('Loading sequence #%d (%s, %s, %s)\n', i, ...
	he.SubjectName, he.ActionType, he.Trial);
camera = upper(input('Choose the camera: ', 's'));
vs = VideoStream('heData', he, 'camera', camera);
vs.modelBackground();

for i = 1:3:vs.nFrames
	subplot(1, 2, 1);
	imshow(vs.at(i));
	subplot(1, 2, 2);
	imshow(vs.bwAt(i));
	xlabel(['#', num2str(i)])
	pause;
end
