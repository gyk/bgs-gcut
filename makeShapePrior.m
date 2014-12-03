function [sp] = makeShapePrior(joints2d, imSize)
	assert(all(size(joints2d) == [15, 2]));
	% difference in Y axis indicates the height of the actor
	yDev = minmax(joints2d(:, 2)');
	yDev = yDev(2) - yDev(1);
	sp = SkeletonDrawer.drawAsShapePrior(joints2d, imSize);
	sp = bwdist(sp);
	% TODO: choose better parameters
	sp = 1 ./ (1 + exp(0.15 * (sp - yDev / 18)));
end
