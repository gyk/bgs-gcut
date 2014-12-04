classdef MathHelper
	properties (Constant)
	% scale parameter from MAD to SD
	MAD_TO_SD = 1 / norminv(3 / 4);
	end

	methods (Static)
	function d = angleDiff(th1, th2)
	% Returns the difference between two angles in radians.
	% This will always be <= pi.
		d = pi - abs(mod(th1 - th2, 2*pi) - pi);
	end

	function pMean = polarMean(th, dim)
	% Returns the "mean" of a set of angular values
		if ~exist('dim', 'var')
			dim = 1;
		end

		% We can't simply write `pMean = mean(th);` as it gets 
		% the wrong answer for `th = [1/6*pi, -1/6*pi]`.
		% Hence we assume all angles lie on the unit circle and convert
		% them to complex numbers, compute the mean and then convert it 
		% back to polar coordinates.
		pMean = mod(angle(mean(exp(1.0i * th), dim)), 2*pi);
	end

	function [mean1, std1] = mergeStats(means, stds, ns)
		assert(std([numel(means), numel(stds), numel(ns)]) == 0);
		nCases = numel(ns);
		allN = sum(ns);

		mean1 = zeros(size(means{1}));
		std1 = zeros(size(stds{1}));
		for i = 1:nCases
			mean1 = mean1 + means{i} * ns(i);
		end
		mean1 = mean1 ./ allN;

		for i = 1:nCases
			std1 = std1 + (stds{i} .^ 2) .* (ns(i) - 1) + ...
				((means{i} - mean1) .^ 2) .* ns(i);
		end
		std1 = (std1 ./ (allN - 1)) .^ 0.5;
	end
	end
end
