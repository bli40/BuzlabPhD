filename = 'photometry_data.mat';
ppd_file = 'B:\Brian\N18\N18_260217_sess7\N18_260217_160210\brian18-2026-02-17-155658.ppd'; %% user defined;
data = my_process_photometry_v6(ppd_file, 'isplot', false);
save(filename, 'data');
hj_getAnalogPulses('analogCh',6);
align_photometry_intan;
