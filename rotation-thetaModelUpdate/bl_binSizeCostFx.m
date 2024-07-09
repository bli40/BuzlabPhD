function cost = bl_binSizeCostFx(k_mu,k_var,nTrials,binWidth)
% COMPUTE cost function for bin size selection for time-histogram firing
% rate estimation
%   Algorithm 1 detailed in Shimazaki & Shinomoto, 2007

    numerator = (2*k_mu) - k_var;
    denominator = (nTrials*binWidth)^2;

    cost = numerator/denominator;



end