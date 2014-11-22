classdef HEUtilities

	methods (Static)
	function extractPoses(heDataset, suffix)
	% Extracts pose coordinates from C3D mocap files.
	% Saved as .mat files.
	% 
	% suffix: the output file will be ($basename).($suffix).mat
		if suffix(1) ~= '.'
			suffix = ['.' suffix];
		end

		makeDstPath = @(subject, baseName) fullfile(CONFIG.HE_PATH, subject, ...
			'Mocap_Data_Packed', [baseName, suffix, '.mat']);

		% Suppresses the "Warning: Bad marker data" message.
		warning('off', 'HumanEva:MarkerCoord2Xform');

		for i = 1:length(heDataset)
			he = heDataset(i);
			subject = he.SubjectName;
			action = he.ActionType;
			trial = he.Trial;

			fprintf('Loading sequence #%d (%s, %s, %s)\n', i, subject, action, trial);

			% the static C3D MoCap data
			c3dStatic = c3d_st_path(he);
			% measurement data
			mp = mp_path(he);
			% C3D MoCap data (the actual motion data)
			c3d = c3d_path(he);

			% creates the mocap stream
			% 
			% WORKAROUND:
			% I have to pass offset = 1 to create mocap_stream (which defaults to 0) 
			% because otherwise it will raise an error:
			% 
			%   ??? Subscript indices must either be real positive integers or 
			%   logicals.
			% 
			%   Error in ==> mocap_stream.cur_frame at 111
			%   if (any(sum(this.data.Markers(floor(this.current_position), ...
			%       midx, :),3) == 0))
			% 
			% And actually the last valid frame is he_dataset.FrameEnd + 1. 
			% Hence if offset = 0 is passed, it should loop from frameStart 
			% to frameEnd + 1.
			% It may be a bug of HumanEva's code.

			mocapStream = mocap_stream(c3d, c3dStatic, mp, 1);
			destPath = makeDstPath(subject, [action, '_', trial]);

			if exist(destPath, 'file')
				fprintf('File #%d "%s" exists. Ignored.\n--------\n', ...
					i, destPath);
				continue;
			end

			frameStart = he.FrameStart;
			frameEnd = he.FrameEnd;

			% the coordinates to be written to the disk
			coordinates = zeros(frameEnd - frameStart + 1, 14 * 3);
			% the coordinate of the pelvis joint (root)
			origins = zeros(frameEnd, 3);

			% NOTE: The Train data of trial #1 starts at half the length 
			% of the whole mocap stream.

			% the frame No. of each pose coordinate
			frameNo = zeros(frameEnd, 1);
			validFrameCounter = 0;
			
			for frmInd = frameStart:frameEnd
				fprintf('Frame #%d\n', frmInd);
				
				[mocapStream, groundTruthPose, isValid] = ...
					cur_frame(mocapStream, frmInd, 'body_pose');

				if (isValid)
					[coords, org] = to_coords(groundTruthPose);
					validFrameCounter = validFrameCounter + 1;
					frameNo(frmInd) = validFrameCounter;
					coordinates(validFrameCounter, :) = coords;
					origins(validFrameCounter, :) = org;
				else
					frameNo(frmInd) = 0;
					fprintf('Frame #%d is invalid!\n', frmInd);
				end
			end

			coordinates(validFrameCounter+1:end, :) = [];

			% saves to disk
			HEUtilities.tryMkdir(destPath);
			save(destPath, 'coordinates', 'frameNo', 'origins');
			fprintf('\nSaved.\n');
		end
		warning('on', 'HumanEva:MarkerCoord2Xform');
		fprintf('\nDone.\n');
	end

	function [heDataset] = select(predicate)
	% predicate: a partition will be selected if predicate(partition) 
	%     == true. e.g. @(part) isequal(part.ActionType, 'Jog');
	%   
		heDataset = he_dataset('HumanEvaI', 'All');

		flags = false(numel(heDataset), 1);

		for i = 1:numel(heDataset)
			if predicate(heDataset(i))
				flags(i) = true;
			end
		end

		heDataset = heDataset(flags);
	end

	function tryMkdir(path)
		folder = fileparts(path);
		if ~exist(folder, 'dir')
			mkdir(folder);
		end
	end
	end
end
