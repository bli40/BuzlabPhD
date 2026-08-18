function [outputArg1,outputArg2] = untitled2(inputArg1,inputArg2)
    switch lower(event)
        case "ripples"
            eventTimes_hpc = ripples.timestamps(:,1);
            eventTimes_str = ripples.timestamps(:,1);
        case "stims"
            eventTimes_hpc = photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOn);
            eventTimes_str = photometry_STR_sync_concat.timestamps(photometry_STR_sync_concat.barcodesOn);
        case "long stim"
            eventTimes_hpc = photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOn(stimDur == 3));
            eventTimes_str = photometry_STR_sync_concat.timestamps(photometry_STR_sync_concat.barcodesOn(stimDur == 3));
        case "short stim"
            eventTimes_hpc = photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOn(stimDur == 0.5));
            eventTimes_str = photometry_STR_sync_concat.timestamps(photometry_STR_sync_concat.barcodesOn(stimDur == 0.5));
        case "nosepokes"
            eventTimes_hpc = behavTrials.timestamps;
            eventTimes_str = behavTrials.timestamps;
        case "rewarded pokes"
            eventTimes_hpc = behavTrials.timestamps(logical(behavTrials.reward_outcome));
            eventTimes_str = behavTrials.timestamps(logical(behavTrials.reward_outcome));
        case "unrewarded pokes"
            eventTimes_hpc = behavTrials.timestamps(~logical(behavTrials.reward_outcome));
            eventTimes_str = behavTrials.timestamps(~logical(behavTrials.reward_outcome));
        case "first in duos"
            idx = rippleBurst.first & rippleBurst.duos;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        case "second in duos"
            idx = rippleBurst.second & rippleBurst.duos;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        case "first in trios"
            idx = rippleBurst.first & rippleBurst.trios;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        case "second in trios"
            idx = rippleBurst.second & rippleBurst.trios;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        case "third in trios"
            idx = rippleBurst.third & rippleBurst.trios;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        otherwise
            if isfield(rippleBurst, event)
                eventTimes_hpc = ripples.timestamps(rippleBurst.(event),1);
                eventTimes_str = ripples.timestamps(rippleBurst.(event),1);
            else
                fprintf('%s is not a registered event type. Halting.\n',event);
                break;
            end
    end
end