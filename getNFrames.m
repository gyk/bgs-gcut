function [nFrames] = getNFrames(videoReader)
	if isempty(videoReader.NumberOfFrames)
		[~, ~, ext] = fileparts(videoReader.Name);
		if isequal(ext, '.avi')
			warning('off', 'MATLAB:aviinfo:FunctionToBeRemoved');
			vInfo = aviinfo(fullfile(videoReader.Path, videoReader.Name));
			% sometimes `aviinfo` overestimates the number of frames
			nFrames = vInfo.NumFrames - 3;
		else
			videoReader.read(Inf);
			nFrames = videoReader.NumberOfFrames;
		end
	else
		nFrames = videoReader.NumberOfFrames;
	end
end
