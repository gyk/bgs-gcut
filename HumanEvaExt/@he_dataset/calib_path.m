function [p] = calib_path(he, cam)
	assert(isstr(cam));
	baseName = sprintf('%s.cal', cam);
	p = fullfile(CONFIG.HE_PATH, he.SubjectName, 'Calibration_Data', baseName);
end
