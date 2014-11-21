function [p] = c3d_st_path(he)
	p = fullfile(CONFIG.HE_PATH, he.SubjectName, 'Mocap_Data', ...
		'Static.c3d');
end
