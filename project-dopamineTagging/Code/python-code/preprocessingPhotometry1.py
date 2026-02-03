## 2026-01-24: BYL adapted from Lucy's code to preprocess entire sessions' data.
# For analyzing pyphotometry data. Similar to pyphotometry_preprocessing.py, but plots fewer things 
# and uses the pyphotometry function preprocess_data. 

import os
import numpy as np
import pandas as pd
import openpyxl
import matplotlib.pyplot as plt
from scipy.signal import medfilt, butter, filtfilt
from scipy.stats import linregress
from scipy.optimize import curve_fit, minimize
import scipy
from github_code_ipshita.tools.data_import import import_ppd, preprocess_data
from pathlib import Path

directory_path = Path(
    r'\\research-cifs.nyumc.org\research\buzsakilab\Buzsakilabspace\LabShare'
    r'\BrianLi\project-dopamine-tagging\data-directories.xlsx')
directory = pd.read_excel(directory_path)
df = pd.DataFrame({
    "Use": directory.Use,
    "Session": [p.split('\\')[-1] for p in directory.Path],
    "Path": directory.Path})

# create new "Use" column if need be:
idx = df.Use == 1;
print(df.Session[idx])

answer = input("Continue? [y/n]: ")
if answer.lower() in ["y","yes"]:
    for sesh in df.Path:
        print(sesh)
        data_folder = Path(sesh)
        
        # Find all subdirectories
        subdirs = [d for d in data_folder.iterdir() if d.is_dir()]

        for subdir in data_folder.glob("N*_*"):
            if not subdir.is_dir():
                continue
            print(f"\nENTERING {subdir}")

            # Find photometry files
            photometry_files = sorted(subdir.glob("*.ppd"))

            for ppd_file in photometry_files:
                print(f"    PROCESSING {ppd_file}")

                # Import data
                data = import_ppd(ppd_file)   #, low_pass=20, high_pass=0.001)
                grabDA_raw = data['analog_1'] # green 
                cherry_raw = data['analog_2'] # red
                stimpulse = data['digital_1']
                syncpulse = data['digital_2']
                time_seconds = data['time']/1000
                sampling_rate = data['sampling_rate']
                time = data['time']

                preprocessed_data = {}

                processed_signal = preprocess_data(data_dict=data, 
                                                   signal="analog_1", 
                                                   control="analog_2", 
                                                   low_pass=10,
                                                   normalisation="dF/F",
                                                   plot=True,
                                                   fig_path = os.path.join(os.path.expanduser('~'), 'Downloads', 'N7_striatum.png'))  # change name you want to save as

                # Save plot to the Downloads folder
                #downloads_path = os.path.join(os.path.expanduser('~'), 'Downloads', 'N7_striatum_plot.png')
                #plt.gcf().savefig(downloads_path)

                # Plot raw signals
                fig,ax1=plt.subplots()  # create a plot to allow for dual y-axes plotting
                plot1=ax1.plot(time_seconds, grabDA_raw, 'g', label='grabDA') #plot grabDA on left y-axis
                ax2=plt.twinx()# create a right y-axis, sharing x-axis on the same plot
                plot2=ax2.plot(time_seconds, cherry_raw, 'r', label='mCherry') # plot mCherry on right y-axis

                # Add labels for both axes
                ax1.set_xlabel('Time (seconds)')
                ax1.set_ylabel('grabDA_raw', color='g')
                ax2.set_ylabel('mCherry', color='r')

                plt.show(block=False)
                plt.pause(5)
                plt.close()


                # Plot rewards times as ticks.
                #reward_ticks = ax1.plot(reward_cue_times, np.full(np.size(reward_cue_times), 1.625), label='Reward Cue', color='w', marker="|", mec='k')


                # Get stimulation and synchronization pulse timestamps
                # barcodes on and off are giving indices of timestamp where the barcode goes on or off

                stimpulseOn = []
                stimpulseOff = []
                for i,signal in enumerate(stimpulse):
                    if signal == 1 and stimpulse[i-1]==0:
                        stimpulse_On = i
                        stimpulseOn.append(i)
                    if signal == 0 and stimpulse[i-1]==1:
                        stimpulse_Off = i
                        stimpulseOff.append(i)

                stimpulseOnOff = []
                for On,Off in zip(stimpulseOn,stimpulseOff):
                    stimpulseOnOff.append([On, Off])

                stimpulseOn = np.array(stimpulseOn)
                stimpulseOff = np.array(stimpulseOff)


                syncpulseOn = []
                syncpulseOff = []
                for i,signal in enumerate(syncpulse):
                    if signal == 1 and syncpulse[i-1]==0:
                        syncpulse_On = i
                        syncpulseOn.append(i)
                    if signal == 0 and syncpulse[i-1]==1:
                        syncpulse_Off = i
                        syncpulseOff.append(i)

                syncpulseOnOff = []
                for On,Off in zip(syncpulseOn,syncpulseOff):
                    syncpulseOnOff.append([On, Off])

                syncpulseOn = np.array(syncpulseOn)
                syncpulseOff = np.array(syncpulseOff)

                preprocessed_data['sampling_rate'] = sampling_rate
                preprocessed_data['stimpulseOnOff'] = stimpulseOnOff # formerly timestampsOnOff
                preprocessed_data['syncpulseOnOff'] = syncpulseOnOff
                preprocessed_data['highLowSync'] = syncpulse
                preprocessed_data['highLowStim'] = stimpulse
                preprocessed_data['timestamps'] = time_seconds
                preprocessed_data['time_ms'] = time


                # normalisation to save to matlab

                """DENOISING"""
                # Lowpass filter - zero phase filtering (with filtfilt) is used to avoid distorting the signal.
                b,a = butter(2, 10, btype='low', fs=sampling_rate)
                grabDA_denoised = filtfilt(b,a, grabDA_raw)
                cherry_denoised = filtfilt(b,a, cherry_raw)


                """PHOTOBLEACHING CORRECTION"""
                #METHOD 1
                # The double exponential curve we are going to fit.
                def double_exponential(t, const, amp_fast, amp_slow, tau_slow, tau_multiplier):
                    '''Compute a double exponential function with constant offset.
                    Parameters:
                    t       : Time vector in seconds.
                    const   : Amplitude of the constant offset. 
                    amp_fast: Amplitude of the fast component.  
                    amp_slow: Amplitude of the slow component.  
                    tau_slow: Time constant of slow component in seconds.
                    tau_multiplier: Time constant of fast component relative to slow. 
                    '''
                    tau_fast = tau_slow*tau_multiplier
                    return const+amp_slow*np.exp(-t/tau_slow)+amp_fast*np.exp(-t/tau_fast)

                # Fit curve to grabDA signal.
                max_sig = np.max(grabDA_denoised)
                inital_params = [max_sig/2, max_sig/4, max_sig/4, 3600, 0.1]
                bounds = ([0      , 0      , 0      , 600  , 0],
                          [max_sig, max_sig, max_sig, 36000, 1])
                grabDA_parms, parm_cov = curve_fit(double_exponential, time_seconds, grabDA_denoised, 
                                                  p0=inital_params, bounds=bounds, maxfev=1000)
                grabDA_expfit = double_exponential(time_seconds, *grabDA_parms)

                # Fit curve to mCherry signal.
                max_sig = np.max(cherry_denoised)
                inital_params = [max_sig/2, max_sig/4, max_sig/4, 3600, 0.1]
                bounds = ([0      , 0      , 0      , 600  , 0],
                          [max_sig, max_sig, max_sig, 36000, 1])
                cherry_parms, parm_cov = curve_fit(double_exponential, time_seconds, cherry_denoised, 
                                                  p0=inital_params, bounds=bounds, maxfev=1000)
                cherry_expfit = double_exponential(time_seconds, *cherry_parms)

                grabDA_detrended = grabDA_denoised - grabDA_expfit
                cherry_detrended = cherry_denoised - cherry_expfit


                """MOTION CORRECTION"""
                slope, intercept, r_value, p_value, std_err = linregress(x=cherry_detrended, y=grabDA_detrended)

                #print('Slope    : {:.3f}'.format(slope))
                #print('R-squared: {:.3f}'.format(r_value**2))


                grabDA_est_motion = intercept + slope * cherry_detrended
                grabDA_corrected = grabDA_detrended - grabDA_est_motion


                """NORMALIZATION"""
                #METHOD 1: dF/F
                grabDA_dF_F = 100*grabDA_corrected/grabDA_expfit

                #METHOD 2: Z-SCORE
                grabDA_zscored = (grabDA_corrected-np.mean(grabDA_corrected))/np.std(grabDA_corrected)

                preprocessed_data['grabDA_z'] = grabDA_zscored 
                preprocessed_data['grabDA_df'] = grabDA_dF_F
                preprocessed_data['grabDA_raw'] = grabDA_raw

                """ SAVE DATA IN MATLAB FORMAT """
                base = ppd_file.stem.replace("_photometry", "")
                mat_path = ppd_file.with_name(base + "_new_photometry.mat")
                print(f"    SAVING TO {mat_path}")
                scipy.io.savemat(mat_path, {'photometryData': preprocessed_data})

else:
     print('Exiting preprocessingPhotometry1.py')






