function [p] = mp_path(he)
	p = fullfile(CONFIG.HE_PATH, he.SubjectName, 'Mocap_Data', ...
		[he.SubjectName, '.mp']);
end
