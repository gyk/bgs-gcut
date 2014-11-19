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
		addpath(fullfile(CONFIG.HE_CODE_PATH, 'TOOLBOX_dxAvi/'));
		addpath(fullfile(CONFIG.HE_CODE_PATH, 'TOOLBOX_readc3d/'));
		addpath('.\HumanEvaExt');
	end
	end
end
