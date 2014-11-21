function [coords, origin] = to_coords(pose)
% Gets the relative coordinate vector of the given body pose, w.r.t  
% the torsoDistal joint.
%
% Output:
%   coords: 1-by-42 vector;
%   origin: 1-by-3 vector

	coords = zeros(1, 14 * 3);

	% Pelvis joint = (0, 0, 0)
	origin = pose.torsoDistal;
	i = 1;

	% Thorax joint
	coords(i:i+2) = (pose.torsoProximal + pose.headProximal) / 2 - origin;
	i = i + 3;

	% Left shoulder
	coords(i:i+2) = pose.upperLArmProximal - origin;
	i = i + 3;

	% Left elbow
	coords(i:i+2) = (pose.upperLArmDistal + pose.lowerLArmProximal) / 2 - origin;
	i = i + 3;

	% Left wrist
	coords(i:i+2) = pose.lowerLArmDistal - origin;
	i = i + 3;

	% Right shoulder
	coords(i:i+2) = pose.upperRArmProximal - origin;
	i = i + 3;

	% Right elbow
	coords(i:i+2) = (pose.upperRArmDistal + pose.lowerRArmProximal) / 2 - origin;
	i = i + 3;

	% Right wrist
	coords(i:i+2) = pose.lowerRArmDistal - origin;
	i = i + 3;

	% Left hip
	coords(i:i+2) = pose.upperLLegProximal - origin;
	i = i + 3;

	% Left knee
	coords(i:i+2) = (pose.upperLLegDistal + pose.lowerLLegProximal) / 2 - origin;
	i = i + 3;

	% Left ankle
	coords(i:i+2) = pose.lowerLLegDistal - origin;
	i = i + 3;

	% Right hip
	coords(i:i+2) = pose.upperRLegProximal - origin;
	i = i + 3;

	% Right knee
	coords(i:i+2) = (pose.upperRLegDistal + pose.lowerRLegProximal) / 2 - origin;
	i = i + 3;

	% Right ankle
	coords(i:i+2) = pose.lowerRLegDistal - origin;
	i = i + 3;

	% Head (top of the head)
	coords(i:i+2) = pose.headDistal - origin;

end
