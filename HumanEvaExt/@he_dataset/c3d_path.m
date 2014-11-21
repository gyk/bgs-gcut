function [p] = c3d_path(he)
	p = fullfile(CONFIG.HE_PATH, he.SubjectName, 'Mocap_Data', ...
		[he.ActionType, '_', he.Trial, '.c3d']);
end
