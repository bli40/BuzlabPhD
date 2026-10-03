function removeNoiseFromDat(basepath,varargin)
% Edit dat files with different options.
%
% USAGE
%   editDatFile(basepath,ints,varargin)
% 
% INPUT
% basepath      If not provided, takes pwd
% threshold     Intervals to be edited.
% method        'substractMedian' or 'substractMean' (defaut)
% keepDat       Default, false.
%
% <optional>
% option        'remove' or 'zeroes' (default). 
%
% Manu Valero-BuzsakiLab 2021
%
%% Defaults and Parms
p = inputParser;
addParameter(p,'basepath',pwd,@isdir);
addParameter(p,'ch','all');
addParameter(p,'method','subtractMedian',@ischar);
addParameter(p,'keepDat',true,@islogical);

warning('Performing median/mean substraction!!');
parse(p,varargin{:});
ch = p.Results.ch;
method = p.Results.method;
basepath = p.Results.basepath;
keepDat = p.Results.keepDat;

% Get elements
prevPath = pwd;
cd(basepath);

xml = LoadParameters;
fileTargetAmplifier = dir('amplifier*.dat');
if isempty(fileTargetAmplifier)
    filename = split(pwd,filesep); 
    filename = filename{end};
    fileTargetAmplifier = dir([filename '*.dat']);
end

if size(fileTargetAmplifier,1) == 0
    error('Dat file not found!!');
end

if ischar(ch) && strcmpi(ch, 'all')
    ch = 1:length(xml.channels);
end
nChannels = xml.nChannels;
duration = 1 * 60;
frequency = xml.rates.wideband;
fid = fopen(fileTargetAmplifier(1).name,'r'); 
% filename = fileTargetAmplifier(1).name;
C = strsplit(fileTargetAmplifier(1).name,'.dat'); 
filename = [C{1} '_comref.dat'];
filenameOut = [C{1} '_temp.dat'];
fidOutput = fopen(filenameOut,'a');

while 1
    data = fread(fid,[nChannels frequency*duration],'int16');
    if isempty(data)
        break;
    end
    
    if strcmpi('subtractMedian',method)
        m_data = median(data);
    elseif strcmpi('subtractMean',method)
        m_data = mean(data(ch,:));
    end

    data = int16(bsxfun(@minus, data, m_data));
    
    fwrite(fidOutput,data,'int16');
end
fclose(fid);
fclose(fidOutput);

% if keepDat
%     copyfile(filename, [C{1} '_original.dat']);
% end

delete(filename);
movefile(filenameOut, filename);

cd(prevPath);

end