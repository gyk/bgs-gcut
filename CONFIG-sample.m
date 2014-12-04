classdef CONFIG
	properties (Constant)

	HE_PATH = 'F:\HumanEva\';

	HE_CODE_PATH = 'F:\HumanEva\Release_Code_v1_1_beta\';

	% Pre-modelled background means and deviations, only used when the actor 
	% appears almost in the same region of the video.
	% Some experiments show that using it actually compromises 
	% the quality of output videos.
	BG_PATH = 'F:\HumanEva\Background\';

	% frames of videos will be saved here
	SNAPSHOT_PATH = 'F:\silhouette\video\';

	% NOTE: For the action types 'ThrowCatch', 'Gestures' and 'Box', 
	% silhouette extraction must be done using pre-modelled backgrounds.
	% FIXME: for now simply ignore those actions.

	USE_STATIC_BG = @(h) isequal(h.ActionType, 'ThrowCatch') || ...
		isequal(h.ActionType, 'Gestures') || ...
		isequal(h.ActionType, 'Box');

	% Trial 1 has been split into two parts, and the first half is used for 
	% validation and the second half for training.
	% Since our algorithm does not need validation set, the 'Validate' part 
	% is treated as testing set.
	REAL_TR_FILTER = @(h) isequal(h.Trial, '1') && isequal(h.Partition, 'Train') && ...
		~CONFIG.USE_STATIC_BG(h);
	REAL_TR_SUFFIX = 'R_TRAIN';

	REAL_TE_FILTER = @(h) isequal(h.Trial, '1') && isequal(h.Partition, 'Validate') && ...
		~CONFIG.USE_STATIC_BG(h);
	REAL_TE_SUFFIX = 'R_TEST';

	% Trial 2 is reserved for testing, the mocap data for which is withheld to 
	% prevent parameter tuning. You have to submit the results on their crappy 
	% website for evaluation. (No thanks, I would not like to use it.)

	% Trial 3 contains only mocap data and is intended to be used by researchers 
	% interested in learning motion priors.
	% Here we use trial 3 to produce synthetic data for training.
	% So obviously there are no `SYNTH_TE_*`.
	SYNTH_TR_FILTER = @(h) isequal(h.Trial, '3') && ...
		~CONFIG.USE_STATIC_BG(h);
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
