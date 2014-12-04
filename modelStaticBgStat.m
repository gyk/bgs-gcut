function [stBgStat] = modelStaticBgStat(camera)
	camera = upper(camera);
	nRecords = 3;
	allBgStat = cell(nRecords, 1);
	ns = zeros(nRecords, 1);
	for i = 1:nRecords
		baseName = sprintf('Background_%d_(%s).avi', i, camera);
		videoPath = fullfile(CONFIG.BG_PATH, baseName);
		videoReader = VideoReader(videoPath);
		ns(i) = getNFrames(videoReader);

		bgModel = BackgroundModel();
		bgModel.train(videoReader, 200);
		allBgStat{i} = bgModel.bgStat;
	end

	[meansH, meansS, meansV] = deal(cell(nRecords, 1));
	[stdsH, stdsS, stdsV] = deal(cell(nRecords, 1));

	for i = 1:nRecords
		meansH{i} = allBgStat{i}.meanH;
		meansS{i} = allBgStat{i}.meanS;
		meansV{i} = allBgStat{i}.meanV;
		stdsH{i} = allBgStat{i}.devH;
		stdsS{i} = allBgStat{i}.devS;
		stdsV{i} = allBgStat{i}.devV;
	end

	stBgStat = struct();
	[stBgStat.meanH, stBgStat.devH] = MathHelper.mergeStats(meansH, stdsH, ns);
	[stBgStat.meanS, stBgStat.devS] = MathHelper.mergeStats(meansS, stdsS, ns);
	[stBgStat.meanV, stBgStat.devV] = MathHelper.mergeStats(meansV, stdsV, ns);
end
