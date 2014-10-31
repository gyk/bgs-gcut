%% Prepares video
videoPath = fullfile(CONFIG.VIDEO_PATH, 'S2\Image_Data\Walking_1_(C1).avi');
vReader = VideoReader(videoPath);

%% Trains background model
bgModel = BackgroundModel();
bgModel.train(vReader, 200, 3);

%% Extracts foreground for each video frame
nFrames = vReader.NumberOfFrames;
for i = 1:3:nFrames
	im = vReader.read(i);
	fg = bgModel.subtract(im);
	imshow(fg);
	title(['#', num2str(i)])
	pause;
end
