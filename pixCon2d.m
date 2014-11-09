function [conn] = pixCon2d(imageSize, diagWeight)
% Generates graph representation of 8-connected pixels, 
% where the weight of diagonally connected edges is `diagWeight`.
% 
% Set `diagWeight` to 0 if you want 4-connected pixels.
% conn: sparse matrix, size(conn) = imageSize

	if ~exist('diagWeight', 'var')
		diagWeight = 0;
	end

	assert(diagWeight >= 0);

	nRows = imageSize(1);
	nCols = imageSize(2);
	nPixels = nRows * nCols;
	nLinks = ((nRows - 1) * nCols + nRows * (nCols - 1)) * 2;
	indices = (1:nPixels)';

	% horizontal
	iIndH = indices(1:(nPixels - nRows));
	jIndH = indices((1 + nRows):end);
	sH = ones(numel(iIndH), 1);

	% vertical
	t = reshape(indices, [nRows, nCols]);
	iIndV = reshape(t(1:(nRows - 1), :), [nPixels - nCols, 1]);
	jIndV = iIndV + 1;
	sV = ones(numel(iIndV), 1);

	if diagWeight == 0
		[iIndD, jIndD, sD] = deal([]);
		[iIndAD, jIndAD, sAD] = deal([]);
	else
		% diagonal
		iIndD = iIndV(1:(end - (nRows - 1)));
		jIndD = iIndD + (nRows + 1);
		sD = repmat(diagWeight, numel(iIndD), 1);

		% anti-diagonal
		iIndAD = jIndV(1:(end - (nRows - 1)));
		jIndAD = iIndAD + (nRows - 1);
		sAD = repmat(diagWeight, numel(iIndAD), 1);
	end

	% all
	is = [iIndH; iIndV; iIndD; iIndAD];
	js = [jIndH; jIndV; jIndD; jIndAD];
	ss = [sH; sV; sD; sAD];

	assert(numel(is) + numel(js) == nLinks);

	% If symmetric matrix is needed, use
	% 
	%   conn = sparse([is; js], [js; is], [ss; ss], nPixels, nPixels, nLinks);
	
	conn = sparse(is, js, ss, nPixels, nPixels, nLinks);
end
