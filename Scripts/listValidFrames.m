% For each action in HumanEva dataset, lists video frames 
% with valid MoCap data.

REAL_TR.desc = 'Real, Train';
REAL_TR.filter = CONFIG.REAL_TR_FILTER;
REAL_TR.suffix = CONFIG.REAL_TR_SUFFIX;
REAL_TE.desc = 'Real, Test';
REAL_TE.filter = CONFIG.REAL_TE_FILTER;
REAL_TE.suffix = CONFIG.REAL_TE_SUFFIX;
SYNTH_TR.desc = 'Synth, Train';
SYNTH_TR.filter = CONFIG.SYNTH_TR_FILTER;
SYNTH_TR.suffix = CONFIG.SYNTH_TR_SUFFIX;

for scheme = {REAL_TR, REAL_TE, SYNTH_TR}
	scheme = scheme{1};
	fprintf('\n=> Partition: %s\n', scheme.desc);
	hes = HEUtilities.select(scheme.filter);
	assert(iscolumn(hes));

	for i = 1:numel(hes)
		he = hes(i);
		mocapBaseName = sprintf('%s_%s.%s.mat', he.ActionType, he.Trial, ...
			scheme.suffix);
		mocapPath = fullfile(CONFIG.HE_PATH, he.SubjectName, ...
			'Mocap_Data_Packed', mocapBaseName);
		load(mocapPath);  % For `coordinates`, `frameNo` & `origins`

		validInd = find(frameNo ~= 0);
		nValid = length(validInd);
		if nValid == 0
			firstValid = 0;
			lastValid = -1;
		else
			firstValid = validInd(1);
			lastValid = validInd(end);
		end

		fprintf('Sequence (%s, %s, %s)\n', ...
			he.SubjectName, he.ActionType, he.Trial);
		fprintf('Claimed valid frames: [%d, %d], total = /%d\n', ...
			he.FrameStart, he.FrameEnd, he.FrameEnd - he.FrameStart + 1);
		fprintf('Actual valid frames: [%d, %d], total = %d/%d\n', ...
			firstValid, lastValid, nValid, lastValid - firstValid + 1);
		fprintf('\n');
	end
	fprintf('--------------------------------\n');
end
