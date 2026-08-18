%% WIP for behavioral video tracking and arduino event grab
% clear all;
% close all;

cd('C:\Users\brian\Documents\BYL\project-dopamine-tagging\Video\');

%% Get Average Frame
v = VideoReader("M012-06152026160241.mp4");
h = v.Height;
w = v.Width;

isColor = strcmp(v.VideoFormat,'RGB24');

% accumulator in double
if isColor
    sumFrame = zeros(h,w,3,'double');
else
    sumFrame = zeros(h,w,'double');
end
n = 0;

while hasFrame(v)
    f = readFrame(v);
    if ~isColor
        f = f;             % already grayscale
    else
        f = im2double(f);  % convert to double in [0,1]
    end
    if ~isColor
        f = im2double(f);
    end
    sumFrame = sumFrame + f;
    n = n + 1;
end

avgFrame = sumFrame / n;   % average in [0,1]
avgFrame = rgb2gray(avgFrame);          % show averaged image
imshow(avgFrame);

disp('Average Frame Generated')
%% Build Manual Mask

mask = false(h,w);

% Params (tune)
cx = 385; cy = 410;        % center (use your center)
circleRadius = 75;                       % center circle radius
% armLength = [360 350 350 350 350 365 365 365];                         % length of each arm from center
% armWidth = [45 45 45 45 45 45 45 45];                           % width of each arm
armLength = repmat(365, 1, 8);
armWidth = repmat(60, 1, 8);
angles = [19.7:45:360];                  % degrees for arms (even spacing)

% Create circle mask
[xg,yg] = meshgrid(1:w,1:h);
maskCircle = (xg - cx).^2 + (yg - cy).^2 <= circleRadius^2;
mask = mask | maskCircle;

% For each angle, rotate polygon and create mask
for a = 1:numel(angles)
    % Create rectangular arm (centered at origin pointing to +X)
    % define rectangle polygon corners (relative coords)
    rectX = [0 armLength(a) armLength(a) 0] - 0;   % start at center
    rectY = [-armWidth(a)/2 -armWidth(a)/2 armWidth(a)/2 armWidth(a)/2];
    theta = deg2rad(angles(a));
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

%% Use both to create better mask
T = graythresh(avgFrame);
I = imbinarize(avgFrame,max([0 T*0.8]));
newMask = I & mask;
imshow(newMask);

% vidFrame = rgb2gray(readFrame(v));
% vidFrame(~mask) = 0
imshow(avgFrame);
visboundaries(newMask,'Color','r');


%% Track Body Centroid
v = VideoReader("M012-06152026160241.mp4");

% params
minArea = 200;         % minimum blob area to accept (tune)
maxDist = 50;          % max linking distance between frames (pixels)
prevCentroid = [];     % will hold previous centroid

% storage
centroids = nan(1,2);  % grow or preallocate if you know frame count
frameIdx = 0;

while hasFrame(v)
    frameIdx = frameIdx + 1;
    vidFrame = rgb2gray(readFrame(v));
    % vidFrame(~mask) = 0;
    visboundaries(newMask,'Color','r');
    I = imadjust(vidFrame);
    
    % detect dark regions: threshold low intensities
    T = graythresh(I);                  % Otsu on full image
    bw = imbinarize(I, max(0, T*0.5));  % tune factor <1 to pick darker
    bw(~newMask) = 1;                      % restrict to masked region
    bw = ~bw;

    % clean up
    % bw = imopen(bw, strel('disk',3));
    % bw = imclose(bw, strel('disk',10));

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
    
    imshow(vidFrame);
    pause(1/500);
end


% vidFrame is an image matrix (use gray size if color)
if size(vidFrame,3)==3, I = rgb2gray(vidFrame); else I = vidFrame; end

%%
bw = imbinarize(vidFrame, max(0, T*0.7));
imshow(bw)

