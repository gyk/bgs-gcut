classdef CONFIG
	properties (Constant)

	VIDEO_PATH = 'F:\HumanEva\';

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
	end
end
