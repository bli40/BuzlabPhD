%% WIP for behavioral video tracking and arduino event grab

cd('C:\Users\brian\Documents\BYL\project-dopamine-tagging\Video\');

vidObj = VideoReader("BYL-04202026173607-0000.avi");
while hasFrame(vidObj)
    vidFrame = readFrame(vidObj);
    imshow(vidFrame)
    pause(1/vidObj.FrameRate)
end