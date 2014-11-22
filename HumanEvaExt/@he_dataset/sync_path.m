function [p] = sync_path(he, cam)
	assert(isstr(cam));
	baseName = sprintf('%s_%s_(%s).ofs', he.ActionType, he.Trial, cam);
	p = fullfile(CONFIG.HE_PATH, he.SubjectName, 'Sync_Data', baseName);
end
