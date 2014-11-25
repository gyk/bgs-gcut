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
	calibration;

	% For background subtraction
	bgModel;
	end

	properties (Constant)
	% It seems that adding some extra offset value makes video/mocap 
	% synchronized better.
	EXTRA_OFFSET = 2;
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

		if obj.mocapStart < 1
		% nonpositive offset, increase videoStart
			obj.videoStart = round(obj.videoStart - ...
				(obj.mocapStart - 1) / obj.mocapScaling);
		end

		obj.videoReader = VideoReader(video_path(he, obj.camera));
		obj.nFrames = getNFrames(obj.videoReader);

		calibPath = calib_path(he, obj.camera);
		clb = struct();
		[clb.fc, clb.cc, clb.alpha_c, clb.kc, ...
			clb.Rc_ext, clb.omc_ext, clb.Tc_ext] = ReadSpicaCalib(calibPath);
		obj.calibration = clb;
	end

	function im = at(obj, i)
		im = obj.videoReader.read(i);
	end

	function modelBackground(obj)
		bgModelSavePath = [strrep(video_path(obj.heData, obj.camera), ...
			'Image_Data', 'BG_Model'), '.mat'];

		if exist(bgModelSavePath, 'file') == 2
			load(bgModelSavePath);  % for `bgModel`
			obj.bgModel = bgModel;
			return;
		else
			obj.bgModel = BackgroundModel();
			obj.bgModel.train(obj.videoReader, 200);
			bgModel = obj.bgModel;
			HEUtilities.tryMkdir(bgModelSavePath);
			save(bgModelSavePath, 'bgModel');
		end
	end

	function im = bwAt(obj, i)
		error('Not implemented yet.');
	end

	function [pose, origin] = associatedPoseAt(obj, iVideo)
		iMocap = obj.getValidInd(iVideo);
		if iMocap == 0
			pose = [];
			origin = [];
			return;
		end

		pose = obj.coordinates(iMocap, :);
		origin = obj.origins(iMocap, :);
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

	function [joints2d] = projectTo2d(obj, iVideo)
		[pose, origin] = obj.associatedPoseAt(iVideo);
		if isempty(pose)
			joints2d = [];
			return;
		end

		joints3d = [origin', bsxfun(@plus, reshape(pose, [3, 14]), origin')];
		clb = obj.calibration;
		joints2d = project_points2(joints3d, clb.omc_ext, clb.Tc_ext, ...
			clb.fc, clb.cc, clb.kc, clb.alpha_c);
	end

	function videoMocap2dOverlapped(obj)
		mocapIndices = obj.getValidInd((1:obj.nFrames)');

		for iVideo = 1:obj.nFrames
			iMocap = mocapIndices(iVideo);
			if iMocap == 0
				continue;
			end

			imshow(obj.at(iVideo));
			joints2d = obj.projectTo2d(iVideo);
			assert(~isempty(joints2d));

			SkeletonDrawer.draw(joints2d');
			set(gcf, 'Name', sprintf('    %i <-> %i', iVideo, iMocap));
			pause;
		end
	end

	% Video index <-> Mocap index Conversion
	% Here 0 is a placeholder for obj.mocapStart.
	function iMocap = indVideoToMocap(obj, iVideo)
		iVideo = iVideo + VideoStream.EXTRA_OFFSET;
		iMocap = round(0 + ...
			(iVideo - obj.videoStart) * obj.mocapScaling);
	end

	function iVideo = indMocapToVideo(obj, iMocap)
		iVideo = round(obj.videoStart + ...
			(iMocap - 0) / obj.mocapScaling);
		iVideo = iVideo - VideoStream.EXTRA_OFFSET;
	end
	end
end
