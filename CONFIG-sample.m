classdef CONFIG
	properties (Constant)

	HE_PATH = 'F:\HumanEva\';

	HE_CODE_PATH = 'F:\HumanEva\Release_Code_v1_1_beta\';

	% Background means and variances, not been used because
	% some experiments show that using it actually compromises 
	% the quality of output videos.
	BG_PATH = 'F:\HumanEva\Background\';

	% frames of videos will be saved here
	SNAPSHOT_PATH = 'F:\silhouette\video\';

	% NOTE: For now we remove action types 'ThrowCatch' and 'Gestures' because 
	% we do not use pre-modelled backgrounds and silhouettes of these actions 
	% cannot be extracted appropriately.

	% Trial 1 has been split into two parts, and the first half is used for 
	% validation and the second half for training.
	% Since our algorithm does not need validation set, the 'Validate' part 
	% is treated as testing set.
	REAL_TR_FILTER = @(h) isequal(h.Trial, '1') && isequal(h.Partition, 'Train') && ...
		~isequal(h.ActionType, 'ThrowCatch') && ~isequal(h.ActionType, 'Gestures');
	REAL_TR_SUFFIX = 'R_TRAIN';

	REAL_TE_FILTER = @(h) isequal(h.Trial, '1') && isequal(h.Partition, 'Validate') && ...
		~isequal(h.ActionType, 'ThrowCatch') && ~isequal(h.ActionType, 'Gestures');
	REAL_TE_SUFFIX = 'R_TEST';

	% Trial 2 is reserved for testing, the mocap data for which is withheld to 
	% prevent parameter tuning. You have to submit the results on their crappy 
	% website for evaluation. (No thanks, I would not like to use it.)

	% Trial 3 contains only mocap data and is intended to be used by researchers 
	% interested in learning motion priors.
	% Here we use trial 3 to produce synthetic data for training.
	% So obviously there are no `SYNTH_TE_*`.
	SYNTH_TR_FILTER = @(h) isequal(h.Trial, '3') && ...
		~isequal(h.ActionType, 'ThrowCatch') && ~isequal(h.ActionType, 'Gestures');
	SYNTH_TR_SUFFIX = 'S_TRAIN';
	end

	methods (Static)
	function compile()
		mex -O pixCon.cpp
		mex -O gcut.cpp
	end

	function addPaths()
		addpath(CONFIG.HE_CODE_PATH);
		addpath(fullfile(CONFIG.HE_CODE_PATH, 'TOOLBOX_calib/'));
		addpath(fullfile(CONFIG.HE_CODE_PATH, 'TOOLBOX_common/'));
		addpath(fullfile(CONFIG.HE_CODE_PATH, 'TOOLBOX_readc3d/'));
		addpath('.\HumanEvaExt');
	end
	end
end
