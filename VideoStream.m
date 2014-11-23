classdef VideoStream < handle
	properties
	heData;
	camera;

	coordinates;
	frameNo;
	origins;

	videoStart;
	mocapStart;
	mocapScaling;

	videoReader;
	nFrames;
	end

	methods
	function obj = VideoStream(varargin)
		p = inputParser;
		addParamValue(p, 'heData', [], ...
			@(x) isequal(class(x), 'he_dataset') && numel(x) == 1);
		addParamValue(p, 'camera', 'C3', ...
			@(x) regexp(x, '^(C[1-3]|BW[1-4])$'));

		parse(p, varargin{:});

		obj.heData = p.Results.heData;
		he = obj.heData;
		obj.camera = p.Results.camera;

		mocapBaseName = sprintf('%s_%s.%s.mat', he.ActionType, he.Trial, ...
			CONFIG.REAL_TE_SUFFIX);
		mocapPath = fullfile(CONFIG.HE_PATH, he.SubjectName, ...
			'Mocap_Data_Packed', mocapBaseName);
		load(mocapPath);  % For `coordinates`, `frameNo` & `origins`

		obj.coordinates = coordinates;
		obj.frameNo = frameNo;
		obj.origins = origins;

		offset = load(sync_path(he, obj.camera));
		obj.videoStart = offset(1);
		obj.mocapStart = offset(2);
		obj.mocapScaling = offset(3);

		obj.videoReader = VideoReader(video_path(he, obj.camera));
		obj.nFrames = getNFrames(obj.videoReader);
	end

	function im = at(obj, i)
		im = obj.videoReader.read(i);
	end

	function im = bwAt(obj, i)
		error('Not implemented yet.');
	end

	function pose = associatedPoseAt(obj, iVideo)
		iMocap = obj.getValidInd(i);
		if iMocap == 0
			pose = [];
			return;
		end

		pose = obj.coordinates(iMocap, :);
	end

	function iMocap = getValidInd(obj, iVideo)
	% where iMocap(i) == 0 indicates invalid mocap data
		iMocap = obj.indVideoToMocap(iVideo);
		iMocap(iMocap < 0 | iMocap > size(obj.frameNo, 1)) = 0;
		iMocap(iMocap > 0) = obj.frameNo(iMocap(iMocap > 0));
	end

	function videoMocapSideBySide(obj)
		mocapIndices = obj.getValidInd((1:obj.nFrames)');

		for iVideo = 1:obj.nFrames
			iMocap = mocapIndices(iVideo);
			if iMocap == 0
				continue;
			end

			subplot(1, 2, 1);
			imshow(obj.at(iVideo));
			subplot(1, 2, 2);
			SkeletonDrawer.draw(obj.coordinates(iMocap, :));
			set(gcf, 'Name', sprintf('    %i <-> %i', iVideo, iMocap));
			pause;
		end
	end

	% Video index <-> Mocap index Conversion
	% Here 0 is a placeholder for obj.mocapStart.
	function iMocap = indVideoToMocap(obj, iVideo)
		iMocap = round(0 + ...
			(iVideo - obj.videoStart) * obj.mocapScaling);
	end

	function iVideo = indMocapToVideo(obj, iMocap)
		iVideo = round(obj.videoStart + ...
			(iMocap - 0) / obj.mocapScaling);
	end
	end
end
