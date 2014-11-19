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
