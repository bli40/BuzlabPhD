% Function for preprocessing pyPhotometry data files in Matlab.
function data = my_process_photometry_v6(filename, varargin)
    % Function to import pyPhotometry binary data files into Matlab.
    % Applies lowpass filtering, polynomial baseline correction, dF/F calculation,
    % robust outlier handling, and peak/trough detection for 5HT (Serotonin) and Ach signals.

    if ~strcmp(filename(end-3:end), '.ppd')
        error('Filename must have extension .ppd');
    end

    % Parse input parameters
    p = inputParser;
    addParameter(p,'pol_order',3, @isnumeric);
    addParameter(p,'fc',20, @isnumeric); % Cutoff for initial raw data filter
    addParameter(p,'filt_order',4, @isnumeric); % Filter order for initial raw data filter
    addParameter(p,'fc_peaks', 5, @isnumeric); % Cutoff for smoothing dFF for peak detection
    addParameter(p,'filt_order_peaks', 2, @isnumeric); % Filter order for smoothing dFF for peak detection
    addParameter(p, 'isplot', true, @islogical);
    parse(p,varargin{:});

    % Import photometry data from the file
    photometry_data = hj_import_ppd(filename);

    % Extract raw data and time information
    FiveHT_raw = photometry_data.analog_1; % Serotonin
    Ach_raw = photometry_data.analog_2;
    time_seconds = photometry_data.time/1000;
    sampling_rate = photometry_data.sampling_rate;
    trial_onset = photometry_data.digital_2;
    photometry_align = photometry_data.digital_1;

    % Restrict analysis to the full data
    cutoff_idx = floor(length(time_seconds) * 1);
    FiveHT_raw = FiveHT_raw(1:cutoff_idx);
    Ach_raw = Ach_raw(1:cutoff_idx);
    time_seconds = time_seconds(1:cutoff_idx);
    trial_onset = trial_onset(1:cutoff_idx);
    photometry_align = photometry_align(1:cutoff_idx);

    % Initialize outputs as empty
    FiveHT_denoised = [];
    Ach_denoised = [];
    FiveHT_baseline = [];
    Ach_baseline = [];
    dFF_FiveHT = [];
    dFF_Ach = [];
    dFF_FiveHT_cleaned = [];
    dFF_Ach_cleaned = [];
    dFF_FiveHT_cleaned_z = [];
    dFF_Ach_cleaned_z = [];
    dFF_FiveHT_smoothed = [];
    dFF_Ach_smoothed = [];

    % --- Only process if signal exists ---
    if ~isempty(FiveHT_raw) && all(isfinite(FiveHT_raw))
        [b_raw,a_raw] = butter(p.Results.filt_order, p.Results.fc/(sampling_rate/2), 'low');
        FiveHT_denoised = filtfilt(b_raw,a_raw, FiveHT_raw);
        p1 = polyfit(time_seconds',FiveHT_denoised,p.Results.pol_order);
        FiveHT_baseline = polyval(p1,time_seconds');
        dFF_FiveHT = (FiveHT_denoised - FiveHT_baseline)./FiveHT_baseline;
        win = round(sampling_rate * 10);
        is_outlier_FiveHT = isoutlier(dFF_FiveHT, 'movmedian', win);
        dFF_FiveHT_cleaned = dFF_FiveHT;
        dFF_FiveHT_cleaned(is_outlier_FiveHT) = NaN;
        dFF_FiveHT_cleaned = fillmissing(dFF_FiveHT_cleaned, 'pchip');
        dFF_FiveHT_cleaned_z = zscore(dFF_FiveHT_cleaned);
        [b_peaks,a_peaks] = butter(p.Results.filt_order_peaks, p.Results.fc_peaks/(sampling_rate/2), 'low');
        dFF_FiveHT_smoothed = filtfilt(b_peaks,a_peaks, dFF_FiveHT_cleaned);
    else
        b_raw = []; a_raw = []; b_peaks = []; a_peaks = []; p1 = [];
    end

    if ~isempty(Ach_raw) && all(isfinite(Ach_raw))
        [b_raw,a_raw] = butter(p.Results.filt_order, p.Results.fc/(sampling_rate/2), 'low');
        Ach_denoised = filtfilt(b_raw,a_raw, Ach_raw);
        p2 = polyfit(time_seconds',Ach_denoised,p.Results.pol_order);
        Ach_baseline = polyval(p2,time_seconds');
        dFF_Ach = (Ach_denoised - Ach_baseline)./Ach_baseline;
        win = round(sampling_rate * 10);
        is_outlier_Ach = isoutlier(dFF_Ach, 'movmedian', win);
        dFF_Ach_cleaned = dFF_Ach;
        dFF_Ach_cleaned(is_outlier_Ach) = NaN;
        dFF_Ach_cleaned = fillmissing(dFF_Ach_cleaned, 'pchip');
        dFF_Ach_cleaned_z = zscore(dFF_Ach_cleaned);
        [b_peaks,a_peaks] = butter(p.Results.filt_order_peaks, p.Results.fc_peaks/(sampling_rate/2), 'low');
        if all(isfinite(dFF_Ach_cleaned))
            dFF_Ach_smoothed = filtfilt(b_peaks,a_peaks, dFF_Ach_cleaned);
        else
            dFF_Ach_smoothed = [];
        end
    else
        b_raw = []; a_raw = []; b_peaks = []; a_peaks = []; p2 = [];
    end

    % --- Plotting the results ---
    if p.Results.isplot
        figure('Position', [100 100 1600 900]);
        subplot(3,1,1);
        legend_entries = {};
        if ~isempty(dFF_FiveHT) && any(isfinite(dFF_FiveHT))
            plot(time_seconds, zscore(dFF_FiveHT), 'color', [0,0.5,0]); hold on;
            legend_entries{end+1} = '5-HT';
        end
        if ~isempty(dFF_Ach) && any(isfinite(dFF_Ach))
            plot(time_seconds, zscore(dFF_Ach), 'color', [1,0,0]);
            legend_entries{end+1} = 'Ach';
        end
        if isempty(legend_entries)
            text(mean(time_seconds), 0, 'No signal to plot', 'HorizontalAlignment', 'center');
        end
        title('Original dF/F Signals (Z-scored)');
        ylabel('Z-score dF/F');
        if ~isempty(legend_entries)
            legend(legend_entries);
        end
        grid on;

        subplot(3,1,2);
        legend_entries = {};
        if ~isempty(dFF_FiveHT_cleaned) && any(isfinite(dFF_FiveHT_cleaned))
            plot(time_seconds, zscore(dFF_FiveHT_cleaned), 'color', [0,0.5,0]); hold on;
            legend_entries{end+1} = '5-HT';
        end
        if ~isempty(dFF_Ach_cleaned) && any(isfinite(dFF_Ach_cleaned))
            plot(time_seconds, zscore(dFF_Ach_cleaned), 'color', [1,0,0]);
            legend_entries{end+1} = 'Ach';
        end
        if isempty(legend_entries)
            text(mean(time_seconds), 0, 'No cleaned signal to plot', 'HorizontalAlignment', 'center');
        end
        title('Cleaned dF/F Signals (Outlier Removed, Z-scored)');
        ylabel('Z-score dF/F');
        if ~isempty(legend_entries)
            legend(legend_entries);
        end
        grid on;

        subplot(3,1,3);
        legend_entries = {};
        if ~isempty(dFF_FiveHT_smoothed) && any(isfinite(dFF_FiveHT_smoothed))
            plot(time_seconds, zscore(dFF_FiveHT_smoothed), 'color', [0,0.5,0]); hold on;
            legend_entries{end+1} = '5-HT Smoothed';
        end
        if ~isempty(dFF_Ach_smoothed) && any(isfinite(dFF_Ach_smoothed))
            plot(time_seconds, zscore(dFF_Ach_smoothed), 'color', [1,0,0]);
            legend_entries{end+1} = 'Ach Smoothed';
        end
        if isempty(legend_entries)
            text(mean(time_seconds), 0, 'No smoothed signal to plot', 'HorizontalAlignment', 'center');
        end
        title(sprintf('dF/F Signals Smoothed for Peak Detection (fc=%.1f Hz, Z-scored)', p.Results.fc_peaks));
        ylabel('Z-score dF/F');
        if ~isempty(legend_entries)
            legend(legend_entries);
        end
        grid on;
    end

    % Determine trial onset times
    start_times = find(diff(trial_onset) == 1);
    end_times = find(diff(trial_onset) == -1);
    Npulses = min(length(start_times),length(end_times));
    pulse_times= [start_times(1:Npulses) end_times(1:Npulses) end_times(1:Npulses)-start_times(1:Npulses)]/sampling_rate ;

    % Determine photometry alignment pulse times
    start_times_2 = find(diff(photometry_align) == 1);
    end_times_2 = find(diff(photometry_align) == -1);
    Npulses_2 = min(length(start_times_2),length(end_times_2));
    pulse_times_2= [start_times_2(1:Npulses_2) end_times_2(1:Npulses_2) end_times_2(1:Npulses_2)-start_times_2(1:Npulses_2)]/sampling_rate ;

    % Organize data into a structure
    data = struct();
    data.FiveHT_raw = FiveHT_raw;
    data.Ach_raw = Ach_raw;
    data.time_seconds = time_seconds;
    data.sampling_rate = sampling_rate;
    data.trial_onset = trial_onset;                % relabeled
    data.photometry_align = photometry_align;       % relabeled
    data.FiveHT_denoised = FiveHT_denoised;
    data.Ach_denoised = Ach_denoised;
    data.FiveHT_baseline = FiveHT_baseline;
    data.Ach_baseline = Ach_baseline;
    data.dFF_FiveHT = dFF_FiveHT;
    data.dFF_Ach = dFF_Ach;
    data.dFF_FiveHT_cleaned = dFF_FiveHT_cleaned;
    data.dFF_Ach_cleaned = dFF_Ach_cleaned;
    data.dFF_FiveHT_cleaned_z = dFF_FiveHT_cleaned_z;
    data.dFF_Ach_cleaned_z = dFF_Ach_cleaned_z;
    data.dFF_FiveHT_smoothed = dFF_FiveHT_smoothed;
    data.dFF_Ach_smoothed = dFF_Ach_smoothed;
    data.pulse_times = pulse_times;
    data.align_pulse_times = pulse_times_2;
    data.filename = filename;
    data.baseline.p_FiveHT = p1;
    data.baseline.p_Ach = p2;
    data.baseline.FiveHT = FiveHT_baseline;
    data.baseline.Ach = Ach_baseline;
    data.filter.fc = p.Results.fc;
    data.filter.filt_order = p.Results.filt_order;
    data.filter.b = b_raw;
    data.filter.a = a_raw;
    data.filter_peaks.fc = p.Results.fc_peaks;
    data.filter_peaks.filt_order = p.Results.filt_order_peaks;
    data.filter_peaks.b = b_peaks;
    data.filter_peaks.a = a_peaks;

    % Peak and trough detection (using the smoothed signals)
    if ~isempty(dFF_FiveHT_smoothed)
        [~, locs_FiveHT_peaks] = findpeaks(dFF_FiveHT_smoothed, time_seconds, 'MinPeakProminence', 0.01, 'MinPeakDistance', 0.5);
        [~, locs_FiveHT_troughs] = findpeaks(-dFF_FiveHT_smoothed, time_seconds, 'MinPeakProminence', 0.01, 'MinPeakDistance', 0.5);
        if length(locs_FiveHT_peaks) > 1
            FiveHT_peak_intervals = diff(locs_FiveHT_peaks);
            FiveHT_peak_rate = 1 / mean(FiveHT_peak_intervals);
        else
            FiveHT_peak_rate = 0;
        end
        if length(locs_FiveHT_troughs) > 1
            FiveHT_trough_intervals = diff(locs_FiveHT_troughs);
            FiveHT_trough_rate = 1 / mean(FiveHT_trough_intervals);
        else
            FiveHT_trough_rate = 0;
        end
    else
        locs_FiveHT_peaks = []; locs_FiveHT_troughs = [];
        FiveHT_peak_rate = 0; FiveHT_trough_rate = 0;
    end

    if ~isempty(dFF_Ach_smoothed)
        [~, locs_Ach_peaks] = findpeaks(dFF_Ach_smoothed, time_seconds, 'MinPeakProminence', 0.01, 'MinPeakDistance', 0.5);
        [~, locs_Ach_troughs] = findpeaks(-dFF_Ach_smoothed, time_seconds, 'MinPeakProminence', 0.01, 'MinPeakDistance', 0.5);
        if length(locs_Ach_peaks) > 1
            Ach_peak_intervals = diff(locs_Ach_peaks);
            Ach_peak_rate = 1 / mean(Ach_peak_intervals);
        else
            Ach_peak_rate = 0;
        end
        if length(locs_Ach_troughs) > 1
            Ach_trough_intervals = diff(locs_Ach_troughs);
            Ach_trough_rate = 1 / mean(Ach_trough_intervals);
        else
            Ach_trough_rate = 0;
        end
    else
        locs_Ach_peaks = []; locs_Ach_troughs = [];
        Ach_peak_rate = 0; Ach_trough_rate = 0;
    end

    data.FiveHT_denoised = FiveHT_denoised;
    data.Ach_denoised = Ach_denoised;
    data.FiveHT_baseline = FiveHT_baseline;
    data.Ach_baseline = Ach_baseline;
    data.dFF_FiveHT = dFF_FiveHT;
    data.dFF_Ach = dFF_Ach;
    data.dFF_FiveHT_cleaned = dFF_FiveHT_cleaned;
    data.dFF_Ach_cleaned = dFF_Ach_cleaned;
    data.dFF_FiveHT_cleaned_z = dFF_FiveHT_cleaned_z;
    data.dFF_Ach_cleaned_z = dFF_Ach_cleaned_z;
    data.dFF_FiveHT_smoothed = dFF_FiveHT_smoothed;
    data.dFF_Ach_smoothed = dFF_Ach_smoothed;
    data.FiveHT_peak_times = locs_FiveHT_peaks;
    data.FiveHT_trough_times = locs_FiveHT_troughs;
    data.Ach_peak_times = locs_Ach_peaks;
    data.Ach_trough_times = locs_Ach_troughs;
    data.FiveHT_peak_rate = FiveHT_peak_rate;
    data.FiveHT_trough_rate = FiveHT_trough_rate;
    data.Ach_peak_rate = Ach_peak_rate;
    data.Ach_trough_rate = Ach_trough_rate;

end