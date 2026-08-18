function RemoveArtifact_dat(fnameIn,artifact)

%
% INPUT
%     - fnameIn     : source file
%     - artefact   : Nx2 matrix of start end times to interpolate over


fxml = [fnameIn(1:end-4) '.xml'];
if ~exist(fnameIn,'file') && ~exist(fxml,'file')
    error('Dat file and/or Xml file does not exist')
end
sizeInBytes = 2; % change it one day...

syst = LoadXml_old(fxml);


nbChan = syst.nChannels;


fidI = fopen(fnameIn,'r+');
fidO = fidI;

for i = 1:size(artifact,1)
    duration = artifact(i,2)-artifact(i,1);
    nBytes = round(syst.rates.wideband*duration);
    
    start = floor(artifact(i,1)*syst.rates.wideband)*syst.nChannels*sizeInBytes;
    status = fseek(fidI,start,'bof');
    if status ~= 0
        error('Could not start reading (possible reasons include trying to read a closed file or past the end of the file).');
    end
    
    
    
    dat = fread(fidI,nbChan*nBytes,'int16');
    dat = reshape(dat,[nbChan nBytes]);
    n = size(dat,2);
    
    for ii = 1:size(dat,1)
        dat(ii,:) =  interp1([1 n],[dat(ii,1) dat(ii,end)],1:n);
    end
   
    dat = int16(dat(:));
 
    status = fseek(fidI,start,'bof');
    fwrite(fidO,dat,'int16');
end


fclose(fidI);





