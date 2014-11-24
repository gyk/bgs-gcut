classdef SkeletonDrawer
	properties (Access = private)
	bones;
	up;  % UP axis, e.g. [0 1 0]

	% coordinates of sphere
	spX;
	spY;
	spZ;

	% coordinates of cylinder
	cyX;
	cyY;
	cyZ;

	preprocessor;
	end

	methods (Static)
	function draw(poseVec, skeletonType)
		persistent BrownDrawer CMUDrawer

		if ~exist('skeletonType', 'var')
			skeletonType = 'Brown';
		end

		switch skeletonType
		case 'Brown'
			if isempty(BrownDrawer)
				BrownDrawer = SkeletonDrawer(skeletonType);
			end
			drawer = BrownDrawer;
		case 'CMU'
			if isempty(CMUDrawer)
				CMUDrawer = SkeletonDrawer(skeletonType);
			end
			drawer = CMUDrawer;
		otherwise
			error('Unknown skeletonType.');
		end

		if numel(poseVec) == 14 * 3
			drawer.drawSkeleton(poseVec);
		elseif numel(poseVec) == 15 * 2
			drawer.drawPose2d(poseVec);
		else
			error('Unrecognized pose.');
		end
	end

	function drawManyInterp(poseVecs, drawImage)
		lastDrawed = 0;
		function drawImage_(i)
			subplot(1, nSubpanel, 1, 'Parent', panel);
			if i ~= lastDrawed
				drawImage(i);
				lastDrawed = i;
			end
		end

		if exist('drawImage', 'var')
			nSubpanel = 2;
			drawImageF = @drawImage_;
		else
			nSubpanel = 1
			drawImageF = @deal;
		end

		figure(9);
		set(0, 'CurrentFigure', 9);
		set(gcf, 'Toolbar', 'figure')
		clf;

		n = size(poseVecs, 1);
		nInterp = 10;
		alphas = linspace(0, 1, nInterp + 1);
		formatString = ['Frame: %d + %d/' num2str(nInterp)];

		poseBuffer.currentFrame = 0;
		poseBuffer.interp = [];

		panel = uipanel('Title', 'Skeleton', 'FontSize', 12, ...
			'Position', [0 0.15 1 1]);
		
		textSliding = uicontrol('Style', 'text', ...
			'BackgroundColor', [0.8 0.8 0.8], ...
			'FontName', 'Segoe UI', ...
			'HorizontalAlignment', 'left', ...
			'Position', [20 50 120 20]);
		sliderCoarse = uicontrol('Style', 'slider', 'Min', 1, 'Max', n, ...
			'Value', 1, 'SliderStep', [1 / (n - 1), 1 / (n - 1)], ...
			'Position', [150 50 270 20]);
		sliderFine = uicontrol('Style', 'slider', 'Min', 0, 'Max', nInterp, ...
			'Value', 1, 'SliderStep', [1 / nInterp, 1 / nInterp], ...
			'Position', [20 20 400 20]);

		function sliderCoarse_scroll(hObj, event)
			coarse = round(get(sliderCoarse, 'Value'));
			set(sliderFine, 'Value', 0);
			fine = 0;

			subplot(1, nSubpanel, nSubpanel, 'Parent', panel);
			SkeletonDrawer.draw(poseVecs(coarse, :));
			drawImageF(coarse);

			set(textSliding, 'String', sprintf(formatString, coarse, fine));
		end

		function sliderFine_scroll(hObj, event)
			coarse = round(get(sliderCoarse, 'Value'));
			if coarse == n
				set(sliderFine, 'Value', 0);
				return;
			end

			fine = round(get(sliderFine, 'Value'));

			if coarse ~= poseBuffer.currentFrame
				poseFrom = poseVecs(coarse, :);
				poseTo = poseVecs(coarse + 1, :);
				poseBuffer.interp = interpolate(poseFrom, poseTo, alphas);
				poseBuffer.currentFrame = coarse;
			end

			subplot(1, nSubpanel, nSubpanel, 'Parent', panel);
			SkeletonDrawer.draw(poseBuffer.interp(fine + 1, :));
			drawImageF(round(coarse + fine / nInterp));

			set(textSliding, 'String', sprintf(formatString, coarse, fine));
		end

		addlistener(handle(sliderCoarse), 'ActionEvent', @sliderCoarse_scroll);
		addlistener(handle(sliderFine), 'ActionEvent', @sliderFine_scroll);
		sliderCoarse_scroll();
	end

	function poseVec = flipYZ(poseVec)
		poseVec = reshape(poseVec, [3 14]);
		poseVec = poseVec([1 3 2], :);
		poseVec = poseVec(:);
	end
	end

	methods (Access = private)
	function obj = SkeletonDrawer(skeletonType)

		idx = num2cell(2:15);
		switch skeletonType
		case 'Brown'
			Pelvis = 1;
			[Thorax, LeftShoulder, LeftElbow, LeftWrist, ...
				RightShoulder, RightElbow, RightWrist, ...
				LeftHip, LeftKnee, LeftAnkle, ...
				RightHip, RightKnee, RightAnkle, Head] = idx{:};

			obj.bones = [ ...
				Pelvis, LeftHip;
				LeftHip, LeftKnee;
				LeftKnee, LeftAnkle;
				Pelvis, RightHip;
				RightHip, RightKnee;
				RightKnee, RightAnkle;
				Pelvis, Thorax;
				Thorax, LeftShoulder;
				LeftShoulder, LeftElbow;
				LeftElbow, LeftWrist;
				Thorax, RightShoulder;
				RightShoulder, RightElbow;
				RightElbow, RightWrist;
				Thorax, Head;
			];
			r = 30;
			cyR = 20;
			obj.preprocessor = @deal;
		case 'CMU'
			Hips = 1;
			[LeftUpLeg, LeftLeg, LeftFoot, ...
				RightUpLeg, RightLeg, RightFoot, Spine, ...
				LeftArm, LeftForeArm, LeftHand, ...
				RightArm, RightForeArm, RightHand, Head] = idx{:};
			obj.bones = [ ...
				Hips, LeftUpLeg;
				LeftUpLeg, LeftLeg;
				LeftLeg, LeftFoot;
				Hips, RightUpLeg;
				RightUpLeg, RightLeg;
				RightLeg, RightFoot;
				Hips, Spine;
				Spine, LeftArm;
				LeftArm, LeftForeArm;
				LeftForeArm, LeftHand;
				Spine, RightArm;
				RightArm, RightForeArm;
				RightForeArm, RightHand;
				Spine, Head;
			];
			r = 0.525;
			cyR = 0.35;

			obj.preprocessor = @SkeletonDrawer.flipYZ;
		end

		
		[obj.spX, obj.spY, obj.spZ] = sphere();  % a unit sphere
		obj.spX = obj.spX * r;
		obj.spY = obj.spY * r;
		obj.spZ = obj.spZ * r;

		[obj.cyX obj.cyY obj.cyZ] = cylinder(cyR);
		% [obj.cyX obj.cyY obj.cyZ] = ellipsoid(0, 0, 0.5, 32, 32, 0.5);

	end

	function drawSkeleton(obj, poseVec)
		poseVec = obj.preprocessor(poseVec);
		pose(2:15, :) = reshape(poseVec, [3 14])';

		cla;
		hold on;

		% draws joints
		for i = 1:size(pose, 1)
			p = pose(i, :);
			obj.drawSphere(p(1), p(2), p(3));
		end

		% draws bones
		for i = 1:size(obj.bones, 1)
			fromTo = obj.bones(i, :);
			fromPoint = pose(fromTo(1), :);
			toPoint = pose(fromTo(2), :);

			obj.drawCylinder(fromPoint, toPoint);
		end

		% sets visualization parameters
		axis vis3d;
		axis equal;
		view(180, 10);

		% For rendering to videos, fine-tunes the plot setting.
		axis off;
		% The default dpi is 150
		set(gcf, 'PaperUnits', 'inches', 'PaperPosition', [0 0 2.7 3]);
		% removes large margins around the figure
		set(gca, 'LooseInset', get(gca, 'TightInset'));

		set(gcf, 'Renderer', 'opengl');
		lighting phong;  % or `gouraud`;
		camlight;
		
		hold off;
	end

	function drawSphere(obj, x, y, z)
		surf(obj.spX + x, obj.spY + y, obj.spZ + z, 'EdgeColor', 'none', ...
			'FaceColor', [0.8 0.8 0]);
	end

	function drawCylinder(obj, from, to)
		dirVec = to - from;
		len = norm(dirVec);
		dirVec = dirVec / len;  % normalization
		up = [0 0 1];
		dirDotUp = dot(dirVec, up);

		% handles degenerate cases
		if abs(dirDotUp - 1) < eps
			cs = 1;
			axisRot = [0 1 0];
		elseif abs(dirDotUp + 1) < eps
			cs = -1;
			axisRot = [0 1 0];
		else
			axisRot = cross(up, dirVec);
			axisRot = axisRot / norm(axisRot);  % normalization
			cs = dot(dirVec, up);
		end

		sn = (1 - cs ^ 2) .^ 0.5;
		one_cs = 1 - cs;

		x = axisRot(1); y = axisRot(2); z = axisRot(3);
		% sets rotation matrix
		matRot = [ ...
			cs+x^2*one_cs, x*y*one_cs-z*sn, x*z*one_cs+y*sn; ...
			x*y*one_cs+z*sn, cs+y^2*one_cs, y*z*one_cs-x*sn; ...
			x*z*one_cs-y*sn, y*z*one_cs+x*sn, cs+z^2*one_cs]';

		[m, n] = size(obj.cyX);
		newXYZ = [obj.cyX(:), obj.cyY(:), obj.cyZ(:) * len] * matRot;
		newX = reshape(newXYZ(:, 1), m, n) + from(1);
		newY = reshape(newXYZ(:, 2), m, n) + from(2);
		newZ = reshape(newXYZ(:, 3), m, n) + from(3);

		% Cornflower blue
		surf(newX, newY, newZ, 'EdgeColor', 'none', ...
			'FaceColor', [0.392157, 0.584314, 0.929412]);
	end

	function drawPose2d(obj, pose2d)
		pose = reshape(pose2d, [15, 2]);
		hold on;
		axis ij;
		
		for i = 1:size(obj.bones, 1)
			fromTo = obj.bones(i, :);
			x1 = pose(fromTo(1), 1);
			y1 = pose(fromTo(1), 2);
			x2 = pose(fromTo(2), 1);
			y2 = pose(fromTo(2), 2);
			
			% draws bones
			line([x1, x2], [y1, y2], 'LineWidth', 2, 'LineSmoothing', 'on');
			% draws joints
			plot([x1; x2], [y1; y2], '.g', 'LineWidth', 16);
		end
		axis equal;
		hold off;
	end
	end
end