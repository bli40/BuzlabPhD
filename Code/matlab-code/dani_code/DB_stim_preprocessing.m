basepath = pwd;
[digital_on,digital_off] = Process_IntanDigitalChannels([pwd,'\digitalin.dat']);
save('digitalchannels.mat','digital_on','digital_off');

digiOn = []; digiOff = [];
digiOn = sort(digital_on{1,14});
digiOff = sort(digital_off{1,14});
digiAll = sort([digiOn;digiOff]);
%%
sessionInfo = dir("*sessionInfo.mat");
load(fullfile(sessionInfo.folder, sessionInfo.name));
optogenetics = [];
optogenetics.On = digiOn;
optogenetics.Off = digiOff;
optogenetics.timestamps = digiOn/sessionInfo.rates.wideband;
optogenetics.timestamps(1:numel(digiOn),2) = digiOff/sessionInfo.rates.wideband;
optogenetics.center = optogenetics.timestamps(:,1) + (optogenetics.timestamps(:,2) - optogenetics.timestamps(:,1))/2;
optogenetics.duration = optogenetics.timestamps(:,2) - optogenetics.timestamps(:,1);
optogenetics.intensity = [750 750 750 1050 1050 1050 1350 1350 1350];
save([basepath filesep name '.optogenetics.events.mat'],'optogenetics');


brief_pulses = optogenetics.duration < .01;
other_pulses = ~brief_pulses;
% Brief square pulses - cut the whole pulse duration
artifact_square = [ optogenetics.timestamps( brief_pulses, 1 )-0.00015 optogenetics.timestamps( brief_pulses, 2 )+0.0008 ];
% Other - assume these are intermediate length square pulses, so cut onset and offset
artifact_other_onset = [ optogenetics.timestamps( other_pulses, 1 )-0.00015 optogenetics.timestamps( other_pulses, 1 )+0.0008 ];
artifact_other_offset = [optogenetics.timestamps( other_pulses, 2 )-0.00015 optogenetics.timestamps( other_pulses, 2 )+0.0008 ];
artifact = [artifact_other_onset; artifact_other_offset; artifact_square];
artifact = sort(artifact);


RemoveArtifact_dat([basepath filesep name '.dat'],artifact);


% fprintf('Smoothing artifact edges (chunked)...\n');
% 
% datfile = fullfile(basepath, [basename '.dat']);
% nbChan  = session.extracellular.nChannels;
% fs      = session.extracellular.sr;
% sizeInBytes = 2;
% chunkSamples = 5e5;
% 
% % Define smoothing window
% edgePad = 0.004;  % 2 ms before and after
% edgeSamp = round(edgePad * fs);
% smoothWin = edgeSamp * 2 + 1;
% if mod(smoothWin, 2) == 0
%     smoothWin = smoothWin + 1;
% end
% 
% fid = fopen(datfile, 'r+');
% if fid == -1
%     error('Could not open .dat file for edge smoothing.');
% end
% 
% fseek(fid, 0, 'eof');
% totalSamples = ftell(fid) / (nbChan * sizeInBytes);
% fseek(fid, 0, 'bof');
% 
% chunkStart = 0;
% while chunkStart < totalSamples
%     nSamp = min(chunkSamples, totalSamples - chunkStart);
%     fseek(fid, chunkStart * nbChan * sizeInBytes, 'bof');
%     chunk = fread(fid, [nbChan, nSamp], 'int16=>double');
% 
%     tStart = chunkStart / fs;
%     tEnd   = (chunkStart + nSamp - 1) / fs;
% 
%     overlapping = find( ...
%         (artifact(:,1) <= tEnd + 0.01) & ...
%         (artifact(:,2) >= tStart - 0.01));
% 
%     for i = overlapping(:)'
%         % Smooth ONSET edge
%         s1 = floor((artifact(i,1) * fs)) - chunkStart;
%         s1a = max(1, s1 - edgeSamp);
%         s1b = min(nSamp, s1 + edgeSamp);
%         if s1b > s1a && (s1b - s1a + 1) >= smoothWin
%             chunk(:,s1a:s1b) = sgolayfilt(chunk(:,s1a:s1b).', 2, smoothWin).';
%         end
% 
%         % Smooth OFFSET edge
%         s2 = ceil((artifact(i,2) * fs)) - chunkStart;
%         s2a = max(1, s2 - edgeSamp);
%         s2b = min(nSamp, s2 + edgeSamp);
%         if s2b > s2a && (s2b - s2a + 1) >= smoothWin
%             chunk(:,s2a:s2b) = sgolayfilt(chunk(:,s2a:s2b).', 2, smoothWin).';
%         end
%     end
% 
%     fseek(fid, chunkStart * nbChan * sizeInBytes, 'bof');
%     fwrite(fid, int16(chunk), 'int16');
%     chunkStart = chunkStart + nSamp;
% end
% 
% fclose(fid);
% fprintf('Edge smoothing complete.\n');
% 
% 
% 
% 
% sizeInBytes = 2;
% nbChan = session.extracellular.nChannels;
% chunkSamples = 1e6;
% datfile = [basepath filesep basename '.dat'];
% fid = fopen(datfile,'r+');
% fseek(fid,0,'eof');
% totalSamples = ftell(fid)/(nbChan*sizeInBytes);
% fseek(fid,0,'bof');
% for s = 0:chunkSamples:totalSamples-1
%     nSamp = min(chunkSamples,totalSamples-s);
%     buf = fread(fid,nbChan*nSamp,'int16=>double');
%     if isempty(buf), break, end
%     buf = reshape(buf,nbChan,nSamp);
%     buf = buf - mean(buf,1);
%     fseek(fid,-nbChan*nSamp*sizeInBytes,'cof');
%     fwrite(fid,int16(buf),'int16');
% end
% fclose(fid);

% [digital_on,digital_off] = Process_IntanDigitalChannels([basename,'_digitalin.dat']);
% save('digitalchannels.mat','digital_on','digital_off');
% 
% digiOn = []; digiOff = [];
% digiOn = sort(digital_on{1,3});
% digiOff = sort(digital_off{1,3});
% digiAll = sort([digiOn;digiOff]);
% 
% optoManipulation = [];
% optoManipulation.On = digiOn;
% optoManipulation.Off = digiOff;
% optoManipulation.timestamps = digiOn/session.extracellular.sr;
% optoManipulation.timestamps(1:numel(digiOn),2) = digiOff/session.extracellular.sr;
% optoManipulation.center = optoManipulation.timestamps(:,1) + ...
%     (optoManipulation.timestamps(:,2) - optoManipulation.timestamps(:,1))/2;
% optoManipulation.duration = optoManipulation.timestamps(:,2) - optoManipulation.timestamps(:,1);
% optoManipulation.intensity = [610, 630, 650, 670, 690, 710, 740, 770, 800, 830];
% save([basepath filesep basename '.optoManipulation.manipulation.mat'],'optoManipulation');
% 
% % Define ramp durations per pulse from Arduino sketch
% ramplen_ms   = [2 2 2 10 10 25];                % in ms
% pulsesPerTrn = [2000 2000 2000 2000 2000 500];  % total = 10500
% rampDur_vec = repelem(ramplen_ms / 1000, pulsesPerTrn).';  % in seconds
% 
% prePad  = 0.00015;  % 0.15 ms before
% postPad = 0.0008;   % 0.8 ms after
% 
% brief_pulses = optoManipulation.duration < .025;
% other_pulses = ~brief_pulses;
% 
% % Brief pulses: cut full window
% artifact_square = [ ...
%     optoManipulation.timestamps(brief_pulses,1) - prePad, ...
%     optoManipulation.timestamps(brief_pulses,2) + postPad ];
% 
% % Longer trapezoids: use onset and offset ramp-based windows
% artifact_on = [ ...
%     optoManipulation.timestamps(other_pulses,1) - prePad, ...
%     optoManipulation.timestamps(other_pulses,1) + rampDur_vec(other_pulses) + postPad ];
% 
% artifact_off = [ ...
%     optoManipulation.timestamps(other_pulses,2) - rampDur_vec(other_pulses) - prePad, ...
%     optoManipulation.timestamps(other_pulses,2) + postPad ];
% 
% artifact = sort([artifact_square; artifact_on; artifact_off]);
% 
% Removeartifact_dat([basepath filesep basename '.dat'],artifact);
% 
% sizeInBytes = 2;
% nbChan = session.extracellular.nChannels  ;
% chunkSamples = 1e6;
% datfile = [basepath filesep basename '.dat'];
% fid = fopen(datfile,'r+');
% fseek(fid,0,'eof');
% totalSamples = ftell(fid)/(nbChan*sizeInBytes);
% fseek(fid,0,'bof');
% for s = 0:chunkSamples:totalSamples-1
%     nSamp = min(chunkSamples,totalSamples-s);
%     buf = fread(fid,nbChan*nSamp,'int16=>double');
%     if isempty(buf), break, end
%     buf = reshape(buf,nbChan,nSamp);
%     buf = buf - mean(buf,1);
%     fseek(fid,-nbChan*nSamp*sizeInBytes,'cof');
%     fwrite(fid,int16(buf),'int16');
% end
% fclose(fid);
% 
