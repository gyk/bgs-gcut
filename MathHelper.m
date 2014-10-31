classdef MathHelper
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
	end
end
