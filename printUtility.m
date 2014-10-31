function printInPlace = printUtility(str, n)
% Usage: 
%   printInPlace = printUtility('Processing %d data points: #', nTotal);
% 
%   for i = 1:nTotal
%       doSomeWork();
%       printInPlace(i);
%   end

	printWidth = numel(num2str(n));
	buffer = sprintf(str, n);
	backspaces = repmat(sprintf('\b'), 1, printWidth + 1);

	function [] = printIndexInPlace(i)
		fprintf('%s%*d\n', buffer, printWidth, i);
		buffer = backspaces;
	end

	% If `printInPlace` is never called by the client, 
	% `str` will not be printed either.
	printInPlace = @printIndexInPlace;
end
