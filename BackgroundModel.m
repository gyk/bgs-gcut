classdef BackgroundModel < handle

	properties
	% Parameters: 
	preprocessor;
	dataRange;
	z_H;
	z_V;
	W_H;
	W_S;
	W_V;
	tau;
	Delta_FG;
	diagWeight;
	nu;

	% Data: 
	connections;
	bgStat;
	bgEdges;
	end % properties

	methods
	function obj = BackgroundModel(varargin)

		p = inputParser;
		addParamValue(p, 'dataRange', 0.2, ...
			@(x) isnumeric(x) && x > 0 && x < 1);

		addParamValue(p, 'z_H', 0.1, @isnumeric);
		addParamValue(p, 'z_V', 0.1, @isnumeric);

		addParamValue(p, 'W_H', 0.4, @isnumeric);
		addParamValue(p, 'W_S', 0.2, @isnumeric);
		addParamValue(p, 'W_V', 0.4, @isnumeric);

		addParamValue(p, 'tau', 0.1, @isnumeric);
		addParamValue(p, 'Delta_FG', 1.2, @isnumeric);
		addParamValue(p, 'diagWeight', 0.3204, ...
			@(x) isnumeric(x) && x > 0 && x < 1);
		addParamValue(p, 'nu', 3.0, @isnumeric);

		addParamValue(p, 'preprocessor', @BackgroundModel.videoPreprocess, ...
			@(x) isa(x, 'function_handle'));
		parse(p, varargin{:});

		function setField(fname)
			obj.(fname) = p.Results.(fname);
		end

		setField('dataRange');
		setField('preprocessor');
		setField('z_H');
		setField('z_V');
		setField('W_H');
		setField('W_S');
		setField('W_V');
		setField('tau');
		setField('Delta_FG');
		setField('diagWeight');
		setField('nu');
	end

	function [] = train(obj, videoReader, nSamples, everyNth)
	% The background is modeled on the first `nSamples` frames 
	% using the trim mean and variance on the middle `dataRange` 
	% of the data.

		if ~exist('nSamples', 'var')
			nSamples = 300;
		else
			nSamples = ceil(nSamples);
		end

		if ~exist('everyNth', 'var')
			everyNth = 1;
		end

		nFrames = videoReader.NumberOfFrames;
		endFrame = min(nFrames, everyNth * nSamples - (everyNth - 1));
		endFrame = endFrame - mod(endFrame - 1, everyNth);
		frameInd = [1:everyNth:endFrame];
		nFramesToSample = numel(frameInd);
		fprintf(['Modelling background from #1 to #%d (interval = %d, ', ...
			'total = %d)\n'], endFrame, everyNth, nFramesToSample);

		% inspect
		im = videoReader.read(1);
		if ~isempty(obj.preprocessor)
			im = obj.preprocessor(im);
		end
		assert(isequal(class(im), 'double') && 0 <= min(im(:)), ...
			max(im(:)) <= 1);

		[h, w, nChannels] = size(im);
		assert(nChannels == 3, 'Only support RGB color videos');
		assert(videoReader.Height * w == videoReader.Width * h);
		frames = zeros(h, w, nChannels, nFramesToSample);

		obj.bgStat = struct();
		obj.bgStat.height = h;
		obj.bgStat.width = w;

		% print-in-place
		pip = printUtility('Sampling from %d frames: #', nFrames);

		for i = 1:nFramesToSample
			ind = frameInd(i);
			pip(ind);
			im = videoReader.read(ind);
			if ~isempty(obj.preprocessor)
				im = obj.preprocessor(im);
			end

			% converts to HSV color planes
			frames(:, :, :, i) = rgb2hsv(im);
		end

		nDims = ndims(frames);  % == 4
		% sorts S & V channels
		frames(:, :, 2:3, :) = sort(frames(:, :, 2:3, :), nDims);
		begInd = floor((1 - obj.dataRange) / 2 * nFramesToSample);
		endInd = nFramesToSample - begInd;
		midInd = round((begInd + endInd) / 2);

		% Computes trimmed median. It is mostly equivalent to trimmed 
		% median under the assumption of the paper.
		obj.bgStat.meanS = frames(:, :, 2, midInd);
		obj.bgStat.meanV = frames(:, :, 3, midInd);

		% estimates SD by MAD
		frames(:, :, 2, begInd:endInd) = sort(abs(bsxfun(@minus, ...
			frames(:, :, 2, begInd:endInd), obj.bgStat.meanS)), nDims);
		obj.bgStat.devS = frames(:, :, 2, midInd) * MathHelper.MAD_TO_SD;
		frames(:, :, 3, begInd:endInd) = sort(abs(bsxfun(@minus, ...
			frames(:, :, 3, begInd:endInd), obj.bgStat.meanV)), nDims);
		obj.bgStat.devV = frames(:, :, 3, midInd) * MathHelper.MAD_TO_SD;

		% now we don't need S & V
		frames(:, :, 2:3, :) = [];

		% H should be handled specifically
		meanH_ = MathHelper.polarMean(frames .* (2*pi), 4);

		% Maps H -> [0, 2*pi], and treats \bar{H} as the center hence
		% \bar{H} -> pi.
		% Micro optimization here: the code below is the same as
		% 
		%   frames = mod(bsxfun(@plus, frames .* (2*pi), ...
		%       (pi - meanH_)), 2*pi);
		%   % fits Gaussian
		%   meanH = mod(meanH + meanH_ - pi, 2*pi) / (2*pi);
		% 
		% but runs at least 50% faster when size(frames) == [240, 360, 
		% 1, 250].
		oneOver2Pi = 1 / (2*pi);
		meanH_ = meanH_ .* oneOver2Pi;
		frames = mod(bsxfun(@plus, ...
			frames, (0.5 - meanH_)), 1.0);
		frames(:, :, 1, :) = sort(frames(:, :, 1, :), nDims);
		meanH = frames(:, :, 1, midInd);
		% re-centers the data
		meanH = mod(meanH + meanH_ - 0.5, 1.0);

		obj.bgStat.meanH = meanH;
		frames(:, :, 1, begInd:endInd) = sort(abs(bsxfun(@minus, ...
			frames(:, :, 1, begInd:endInd), obj.bgStat.meanH)), nDims);
		obj.bgStat.devH = frames(:, :, 1, midInd) * MathHelper.MAD_TO_SD;

		obj.setNearToZero();
		obj.setBgEdges();

		% Initializes 4-connected pixels

		% FIXME: diagonal connections should be initialized to the 
		% value `diagWeight`.
		obj.connections = ...
			pixCon([obj.bgStat.height, obj.bgStat.width]);
	end

	function [z] = zScore(obj, imHSV)
		assert(isequal(class(imHSV), 'double'));

		imH = imHSV(:, :, 1);
		imS = imHSV(:, :, 2);
		imV = imHSV(:, :, 3);

		bg = obj.bgStat;

		% Eq. (1)
		dH_ = abs(imH - bg.meanH) .* min(imS, bg.meanS);
		% Eq. (2)
		dH = max(0, 2*pi * dH_ - obj.z_H) ./ bg.devH;
		% Eq. (3)
		dS = abs(imS - bg.meanS) ./ bg.devS;
		% Eq. (4) - something wrong here?
		dV = max(0, abs(imV - bg.meanV + obj.z_V / 2) - obj.z_V) ./ bg.devV;
		z = dH .* obj.W_H + dS .* obj.W_S + dV .* obj.W_V;
	end

	function [] = setNearToZero(obj)
	% prevents divide-by-0 error
		obj.bgStat.meanH = max(obj.bgStat.meanH, 1e-6);
		obj.bgStat.meanS = max(obj.bgStat.meanS, 1e-6);
		obj.bgStat.meanV = max(obj.bgStat.meanV, 1e-6);
		obj.bgStat.devH = max(obj.bgStat.devH, 1e-6);
		obj.bgStat.devS = max(obj.bgStat.devS, 1e-6);
		obj.bgStat.devV = max(obj.bgStat.devV, 1e-6);
	end

	function [connections] = makeConnections(obj, im)
		connections = obj.connections;
		% Cuts off connections where an edge appears in the image
		% frame that is not present in the background model.

		% TODO: implement 8-connected
		V = im(:, :, 3);
		vertical = abs(V(2:end, :) - V(1:end-1, :));
		horizontal = abs(V(:, 2:end) - V(:, 1:end-1));
		connections((vertical - obj.bgEdges.vertical) > obj.tau) = 0;
		connections((horizontal - obj.bgEdges.horizontal) > obj.tau) = 0;
	end

	function [] = setBgEdges(obj)
		% TODO: for simplicity, we use only the V channel to determine 
		% 4-connected edges for now.
		V = obj.bgStat.meanV;
		obj.bgEdges = struct();
		obj.bgEdges.vertical = abs(V(2:end, :) - V(1:end-1, :));
		obj.bgEdges.horizontal = abs(V(:, 2:end) - V(:, 1:end-1));
	end

	function [foreground] = subtractAt(obj, videoReader, i)
		foreground = obj.subtract(videoReader.read(i));
	end

	function [foreground] = subtract(obj, im)
	% foreground: h-by-w matrix where 1s indicate foreground pixels.
		if ~isempty(obj.preprocessor)
			im = obj.preprocessor(im);
		end

		connections = obj.makeConnections(im);
		h = size(im, 1);
		w = size(im, 2);

		hsv = rgb2hsv(im);
		% the edge weights from pixel nodes to source
		bgPenal = obj.zScore(hsv);
		% the edge weights from pixel nodes to sink
		fgPenal = repmat(obj.Delta_FG, size(bgPenal));

		foreground = BackgroundModel.graphCut( ...
			[bgPenal(:)'; fgPenal(:)'], connections);
		foreground = reshape(foreground, [h, w]);
	end
	end % methods

	methods (Static)
	function im = videoPreprocess(im)
		im = imresize(im, 0.5);
		im = double(im) / 255;
	end

	function label = graphCut(C, P)
		assert(size(C, 1) == 2);
		cut = gcut([zeros(2), C; C',P], [1 2]);
		label = ~cut(3:end);
	end
	end % methods (Static)
end
