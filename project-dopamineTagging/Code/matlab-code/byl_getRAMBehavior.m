%% WIP for behavioral video tracking and arduino event grab
clear all;
close all;

cd('C:\Users\brian\Documents\BYL\project-dopamine-tagging\Video\');

vidObj = VideoReader("M011-06122026165547.mp4");
h = vidObj.Height;
w = vidObj.Width;

mask = false(h,w);

% Params (tune)
cx = 385; cy = 410;        % center (use your center)
circleRadius = 75;                       % center circle radius
armLength = 365;                         % length of each arm from center
armWidth = 50;                           % width of each arm
angles = [19.7:45:360];                  % degrees for arms (even spacing)

% Create circle mask
[xg,yg] = meshgrid(1:w,1:h);
maskCircle = (xg - cx).^2 + (yg - cy).^2 <= circleRadius^2;
mask = mask | maskCircle;

% Create rectangular arm (centered at origin pointing to +X)
% define rectangle polygon corners (relative coords)
rectX = [0 armLength armLength 0] - 0;   % start at center
rectY = [-armWidth/2 -armWidth/2 armWidth/2 armWidth/2];

% For each angle, rotate polygon and create mask
for a = angles
    theta = deg2rad(a);
    R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
    pts = R * [rectX; rectY];
    % translate to center
    px = pts(1,:) + cx;
    py = pts(2,:) + cy;
    % polygon mask
    maskArm = poly2mask(px, py, h, w);
    mask = mask | maskArm;
end

% Optional smoothing / fill holes
mask = imclose(mask, strel('disk',3));
mask = imfill(mask,'holes');

figure; hold on;
vidFrame = rgb2gray(readFrame(vidObj));
vidFrame(~mask) = 0
imshow(vidFrame);
% visboundaries(mask,'Color','r');



%% Show
% params
minArea = 200;         % minimum blob area to accept (tune)
maxDist = 50;          % max linking distance between frames (pixels)
prevCentroid = [];     % will hold previous centroid

% storage
centroids = nan(1,2);  % grow or preallocate if you know frame count
frameIdx = 0;

while hasFrame(vidObj)
    frameIdx = frameIdx + 1;
    vidFrame = rgb2gray(readFrame(vidObj));
    vidFrame(~mask) = 0;
    I = imadjust(vidFrame);
    
    % detect dark regions: threshold low intensities
    T = graythresh(I);                  % Otsu on full image
    bw = imbinarize(I, max(0, T*0.5)); % tune factor <1 to pick darker
    bw(~mask) = 1;                      % restrict to masked region

    % clean up
    % bw = imopen(bw, strel('disk',3));
    % bw = imclose(bw, strel('disk',10));
    % bw = bwareaopen(bw, minArea);

    % measure blobs
    s = regionprops(bw, 'Area', 'Centroid', 'BoundingBox');
    if ~isempty(s)
        % choose largest blob
        [~,idxMax] = max([s.Area]);
        c = s(idxMax).Centroid;  % [x y]
        % simple linking: reject if far from previous
        if isempty(prevCentroid) || norm(c - prevCentroid) <= maxDist
            prevCentroid = c;
            centroids(frameIdx,:) = c;
        else
            % if too far, keep previous (or set NaN)
            centroids(frameIdx,:) = NaN;
        end
        % draw marker on frame
        vidFrame = insertShape(vidFrame,'FilledCircle',[c 5],'Color','red','Opacity',1);
    else
        centroids(frameIdx,:) = NaN;
    end
    
    imshow(bw);
    pause(1/500);
end


% vidFrame is an image matrix (use gray size if color)
if size(vidFrame,3)==3, I = rgb2gray(vidFrame); else I = vidFrame; end

%%
bw = imbinarize(vidFrame, max(0, T*0.7));
imshow(bw)

