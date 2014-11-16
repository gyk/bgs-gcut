classdef BackgroundModel < handle

	properties
	% Parameters: 
	preprocessor;
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
	% Setting `nu` to 0 makes the algorithm degenerate to something similar
	% to vanilla mixture of Gaussians: a pixel will be classified as foreground
	% if its weighted deviation > `Delta_FG`.
	% 
	% Neighbor weights are set to 0 where an edge appears in the image. Disable 
	% it by setting `tau` to a value >= 1.

		p = inputParser;
		addParamValue(p, 'z_H', 0.1, @isnumeric);
		addParamValue(p, 'z_V', 0.1, @isnumeric);

		addParamValue(p, 'W_H', 0.4, @isnumeric);
		addParamValue(p, 'W_S', 0.2, @isnumeric);
		addParamValue(p, 'W_V', 0.4, @isnumeric);

		addParamValue(p, 'tau', 0.025, @isnumeric);
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
	% The background is modeled by sampling `nSamples` frames from the  
	% video using median and median absolute deviation as estimators.

		if ~exist('nSamples', 'var')
			nSamples = 300;
		else
			nSamples = ceil(nSamples);
		end

		nFrames = getNFrames(videoReader);

		if ~exist('everyNth', 'var')
			everyNth = nFrames / nSamples;
		end
		assert(everyNth >= 1);

		endFrame = min(nFrames, ceil(everyNth * nSamples - (everyNth - 1)));
		frameInd = round(1:everyNth:endFrame);
		nFramesToSample = numel(frameInd);
		fprintf(['Modelling background from #1 to #%d (interval = %s, ', ...
			'total = %d)\n'], endFrame, num2str(everyNth), nFramesToSample);

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
		midInd = round(nFramesToSample / 2);

		% Computes trimmed median. It is mostly equivalent to trimmed 
		% median under the assumption of the paper.
		obj.bgStat.meanS = frames(:, :, 2, midInd);
		obj.bgStat.meanV = frames(:, :, 3, midInd);

		% estimates SD by MAD
		frames(:, :, 2, :) = sort(abs(bsxfun(@minus, ...
			frames(:, :, 2, :), obj.bgStat.meanS)), nDims);
		obj.bgStat.devS = frames(:, :, 2, midInd) * MathHelper.MAD_TO_SD;
		frames(:, :, 3, :) = sort(abs(bsxfun(@minus, ...
			frames(:, :, 3, :), obj.bgStat.meanV)), nDims);
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
		obj.bgStat.meanH = mod(meanH + meanH_ - 0.5, 1.0);

		frames(:, :, 1, :) = sort(abs(bsxfun(@minus, ...
			frames(:, :, 1, :), meanH)), nDims);
		obj.bgStat.devH = frames(:, :, 1, midInd) * MathHelper.MAD_TO_SD;

		obj.setNearToZero();
		obj.setBgEdges();

		% Initializes 4-connected pixels

		% FIXME: diagonal connections should be initialized to the 
		% value `diagWeight`.
		obj.connections = ...
			pixCon2d([obj.bgStat.height, obj.bgStat.width]);

		fprintf('Done.\n');
	end

	function [z] = zScore(obj, imHSV)
		assert(isequal(class(imHSV), 'double'));

		imH = imHSV(:, :, 1);
		imS = imHSV(:, :, 2);
		imV = imHSV(:, :, 3);

		bg = obj.bgStat;

		% FIXME: I think Eq. (1), (2) and (4) in the original paper might  
		% be incorrect.

		% Eq. (1) - ?
		dH_ = abs(mod(imH - bg.meanH + 0.5, 1) - 0.5) .* ...
			(min(imS, bg.meanS) ./ bg.meanS);
		% Eq. (2) - ?
		dH = max(0, dH_ - obj.z_H) ./ bg.devH;
		% Eq. (3)
		dS = abs(imS - bg.meanS) ./ bg.devS;
		% Eq. (4) - ?
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

		% does not consider edges
		if obj.tau >= 1
			return;
		end

		% Cuts off connections where an edge appears in the image
		% frame that is not present in the background model.

		% TODO: implement 8-connected
		H = im(:, :, 1);
		S = im(:, :, 2);
		V = im(:, :, 3);
		[h, w, ~] = size(im);
		[vertical, horizontal] = BackgroundModel.findEdges(H, S, V);

		vertInd = find([(vertical - obj.bgEdges.vertical) > obj.tau; ...
			zeros(1, w)]);
		horzInd = find([(horizontal - obj.bgEdges.horizontal) > obj.tau, ...
			zeros(h, 1)]);

		[spH, spW] = size(connections);
		spVert = sparse(vertInd, vertInd + 1, true, spH, spW, numel(vertInd));
		spHorz = sparse(horzInd, horzInd + h, true, spH, spW, numel(horzInd));
		connections(spVert) = 0;
		connections(spHorz) = 0;
		assert(nnz(connections) + nnz(spVert) + nnz(spHorz) == nnz(obj.connections));
	end

	function [] = setBgEdges(obj)
		obj.bgEdges = struct();
		[obj.bgEdges.vertical,  obj.bgEdges.horizontal] = ...
			BackgroundModel.findEdges(obj.bgStat.meanH, obj.bgStat.meanS, obj.bgStat.meanV);
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

		% does not set connections between pixel nodes
		if obj.nu == 0
			foreground = bgPenal > obj.Delta_FG;
			return;
		end

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

	function [vertical, horizontal] = findEdges(H, S, V)
		vertH = abs(mod(H(2:end, :) - H(1:end-1, :) + 0.5, 1) - 0.5);
		horzH = abs(mod(H(:, 2:end) - H(:, 1:end-1) + 0.5, 1) - 0.5);

		vertS = abs(S(2:end, :) - S(1:end-1, :));
		horzS = abs(S(:, 2:end) - S(:, 1:end-1));

		vertV = abs(V(2:end, :) - V(1:end-1, :));
		horzV = abs(V(:, 2:end) - V(:, 1:end-1));

		vertical = (vertH + vertS + vertV) * (1/3);
		horizontal = (horzH + horzS + horzV) * (1/3);
	end

	function label = graphCut(C, P)
		assert(size(C, 1) == 2);
		cut = gcut([zeros(2), C; C',P], [1 2]);
		label = ~cut(3:end);
	end
	end % methods (Static)
end
