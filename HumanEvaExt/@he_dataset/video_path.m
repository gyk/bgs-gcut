function [p] = video_path(he, cam)
	assert(isstr(cam));
	baseName = sprintf('%s_%s_(%s).avi', he.ActionType, he.Trial, cam);
	p = fullfile(CONFIG.HE_PATH, he.SubjectName, 'Image_Data', baseName);
end
