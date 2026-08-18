function [digital_on,digital_off] = Process_IntanDigitalChannels(path_digi)
% function gives out the digital inputs as raw datapoints.
% Documentation for Intantech data file formats: http://intantech.com/files/Intan_RHD2000_data_file_formats.pdf
%
% INPUT
% path_digi: full path to the digitalin.dat file
%
% OUTPUTS
% [digital_on,digital_off]: State changes for each digital channel as a cell structure
%
% By Peter Petersen
% petersen.peter@gmail.com

if ~exist(path_digi,'file')
    error(['Intan Digital Channels file does not exist (' path_digi ')'])
else
    disp('Loading digital channels')
    m = memmapfile(path_digi,'Format','uint16','writable',false);
    digital_word2 = double(m.Data);
    clear m
    Nchan = 16;
    Nchan2 = 17;
    
    % Implement below code
%     digital_output_ch = (bitand(digital_word, 2^ch) > 0); % ch has a value of 0-15 here
    for k = 1:Nchan
        digital_word1(:,Nchan2-k) = (digital_word2 - 2^(Nchan-k))>=0;
        digital_word2 = digital_word2 - digital_word1(:,Nchan2-k)*2^(Nchan-k);
        on_states = digital_word1(:,Nchan2-k) == 1;
        state_change = on_states(2:end)-on_states(1:end-1); % diff(test);
        pulses_on{Nchan2-k} = find(state_change == 1);
        pulses_off{Nchan2-k} = find(state_change == -1);
    end
    digital_on = pulses_on;
    digital_off = pulses_off;
    disp('Loading digital channels: Complete')
end
