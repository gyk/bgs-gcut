classdef StatInspector
% A helper class to check whether the computed background
% model is statistically reasonable.
% 
% Just for proving the correctness of the algorithm. Not part 
% of the background subtraction pipeline.

	properties (Constant)
	THREE_SIGMA = normcdf(1:3) * 2 - 1;
	end

	methods (Static)
	function threeSigma(bgStat, vReader, nSamples)
		if ~exist('nSamples', 'var')
			nSamples = 40;
		end

		mH = bgStat.meanH;
		mS = bgStat.meanS;
		mV = bgStat.meanV;

		dHInv = 1 ./ bgStat.devH;
		dSInv = 1 ./ bgStat.devS;
		dVInv = 1 ./ bgStat.devV;

		nPixels = numel(mH);

		sigma.H = [0; 0; 0];
		sigma.S = [0; 0; 0];
		sigma.V = [0; 0; 0];

		nFrames = getNFrames(vReader);
		ind2Smpl = sort(randsample(nFrames, nSamples))';
		assert(isrow(ind2Smpl));
		fprintf('#{Samples} = %d\n', nSamples);
		pip = printUtility('Sampling from %d frames: #', nFrames);
		for ind = ind2Smpl
			pip(ind);
			im = vReader.read(ind);
			im = BackgroundModel.videoPreprocess(im);
			im = rgb2hsv(im);

			H = im(:, :, 1);
			S = im(:, :, 2);
			V = im(:, :, 3);

			absDiffH = floor(abs(H - mH) .* dHInv);
			sigmaH = cumsum(histc(absDiffH(:), 0:2));

			absDiffS = floor(abs(S - mS) .* dSInv);
			sigmaS = cumsum(histc(absDiffS(:), 0:2));

			absDiffV = floor(abs(V - mV) .* dVInv);
			sigmaV = cumsum(histc(absDiffV(:), 0:2));

			sigma.H = sigma.H + sigmaH;
			sigma.S = sigma.S + sigmaS;
			sigma.V = sigma.V + sigmaV;
		end

		fprintf('Normal: 1-sigma: %.4f, 2-sigma: %.4f, 3-sigma: %.4f\n', ...
			StatInspector.THREE_SIGMA);
		fprintf('H: 1-sigma: %f, 2-sigma: %f, 3-sigma: %f\n', ...
			sigma.H ./ (nPixels * nSamples));
		fprintf('S: 1-sigma: %f, 2-sigma: %f, 3-sigma: %f\n', ...
			sigma.S ./ (nPixels * nSamples));
		fprintf('V: 1-sigma: %f, 2-sigma: %f, 3-sigma: %f\n', ...
			sigma.V ./ (nPixels * nSamples));
	end

	function visualizeBgStat(bgStat)
		clf;
		subplot(1, 2, 1);
		im = repmat(bgStat.meanH, [1, 1, 3]);
		im(:,:,2) = bgStat.meanS;
		im(:,:,3) = bgStat.meanV;
		imshow(hsv2rgb(im));
		xlabel('Mean');

		subplot(1, 2, 2);
		im(:,:,1) = bgStat.devH;
		im(:,:,2) = bgStat.devS;
		im(:,:,3) = bgStat.devV;
		scaling = reshape(1 ./ max(max(im)), [1, 1, 3]);
		im = bsxfun(@times, im, scaling);
		imshow(hsv2rgb(im));
		xlabel('SD');
	end

	function visualizeBgEdges(bgEdges, inOne)
		clf;
		if ~exist('inOne', 'var')
			inOne = false;
		end

		if ~inOne
			subplot(1, 2, 1);
			imshow(bgEdges.vertical);
			xlabel('vertical');

			subplot(1, 2, 2);
			imshow(bgEdges.horizontal);
			xlabel('horizontal');
		else
			imshow( ...
				[bgEdges.vertical; ...
					zeros(1, size(bgEdges.vertical, 2))] + ...
				[bgEdges.horizontal, ...
					zeros(size(bgEdges.horizontal, 1), 1)]);
			xlabel('edges');
		end
	end

	function visualizeConnections(connections, h, w)
		if h * w > 10000
			fprintf([
				'This function aims at checking the correctness at ', ...
				'small scale.\nIt is extremly slow for large graph.\n', ...
				'[Paused]\n', ...
			]);
			pause;
		end

		[from, to] = find(connections);

		% Since the connections are symmetric, we only consider the 
		% left -> right / up -> down links.
		leftRight = (to - from  == h);
		upDown = (to - from  == 1);
		from = from(leftRight | upDown);
		to = to(leftRight | upDown);

		[fromR, fromC] = ind2sub([h, w], from);
		[toR, toC] = ind2sub([h, w], to);
		plot([fromR'; toR'], [fromC'; toC'], 'b');
		axis equal;
	end

	function connections2SVG(connections, h, w, filePath)
	% The generated SVG has been tested in Chrome and Firefox.
		[from, to] = find(connections);

		% Since the connections are symmetric, we only consider the 
		% left -> right / up -> down links.
		leftRight = (to - from  == h);
		upDown = (to - from  == 1);
		from = from(leftRight | upDown);
		to = to(leftRight | upDown);

		[fromR, fromC] = ind2sub([h, w], from);
		[toR, toC] = ind2sub([h, w], to);
		svgBegin = sprintf([
			'<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n', ...
			'<svg\n', ...
			'xmlns="http://www.w3.org/2000/svg"\n', ...
			'height="%.0f" width="%.0f">\n', ...
		], h + 2, w + 2);
		svgEnd = '</svg>\n';

		svgBody = sprintf([
			'<line x1="%.0f" y1="%.0f" x2="%.0f" y2="%.0f" ', ...
			'stroke="red" stroke-width="0.1"/>\n', ...
		], [fromC, fromR, toC, toR]');

		fid = fopen(filePath, 'w');
		fprintf(fid, svgBegin);
		fprintf(fid, svgBody);
		fprintf(fid, svgEnd);
		fclose(fid);
	end
	end
end
