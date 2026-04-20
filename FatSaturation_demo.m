%Code snippets by Ariel J. Hannum and the Pulseq demo files restructured as a short example of fat
%saturation with Pulseq (https://pulseq.github.io/).
%Obtained fat saturation pulses may be slotted into any Pulseq sequence,
%see example sequences from the Pulseq main folder.
%Code provided without guarantees regarding efficacy or safety.
%Used in ISMRM 2026 abstract #05996 "Fat Saturation Methods for Diffusion-weighted EPI: A Quantitative Comparison in an Open-source
%Sequence"


sys_rf = mr.opts('MaxGrad',45,'GradUnit','mT/m',...
    'MaxSlew',100,'SlewUnit','T/m/s',...
    'rfRingdownTime', 10e-6, 'rfDeadtime', 100e-6, 'B0', 2.89); %example system parameters, adjust based on used scanner hardware


pulse_type = 'gauss'; %can also be sinc, SLR, adiabatic-wurst, adiabatic-hypsec or none. See Pulseq documentation for details.
                    %wurst pulses were not tested here
sat_ppm = -3.45; %chemical shift in ppm
fat_sat_delay = 220e-3; %inversion time if using STIR,SPIR or SPAIR; add with mr.makeDelay() at the desired position
ssgr_mode = 0; %flag for slice selection gradient reversal; use something like: 
              % if ssgr > 0
              % gz_180 = mr.scaleGrad(gz_180_start,-1);
              % rf_180.freqOffset = rf_180.freqOffset * -1;
              % rf_180.phaseOffset =  rf_180.phaseOffset * -1;
              % end
              % after definition of the refocusing pulse
flip_angle_deg = 180; %flip angle of fatsat pulse
rf_duration = 8e-3; %duration of fatsat pulse
apodization = 0.5; %apodization for sinc pulses
tbw = 4; %time bandwidth product
thickness = 2e-3; %slice thickness
n_fac = 40; %for hypsec pulse design
beta = 200; %for hypsec pulse design;
spoiler_area = 1/1e-4; %spoiler parameters, optional manual definition of amplitude and timings
spoiler_type = 'single'; %can be single, double or none
spoiler_amp = 0;
spoiler_rise_time = 0; 
spoiler_flat_time = 0;


if isequal(pulse_type,'gauss')
    bandwidth = abs(sat_ppm * 1e-6 * sys_rf.B0 * sys_rf.gamma);
    rf = mr.makeGaussPulse(flip_angle_deg * pi / 180, ...
        'system', sys_rf, ...
        'duration', rf_duration, ...
        'bandwidth', bandwidth, ...
        'freqPPM', sat_ppm, ...
        'use', 'saturation');
    rf.phasePPM = -2 * pi * rf.freqPPM * rf.center;
elseif isequal(pulse_type,'slr')
    fs_bw_mul=1.2;
    sat_freq=sat_ppm*1e-6*sys_rf.B0*sys_rf.gamma;
    obj.rf = mr.makeSLRpulse(flip_angle_deg*pi/180, ...
        'duration',rf_duration, ...
        'timeBwProduct',fs_bw_mul*abs(sat_freq)*rf_duration, ...
        'use','saturation',...
        'passbandRipple',1, ...
        'stopbandRipple',1e-2, ...
        'filterType','ms', ...
        'system',sys_rf, ...
        'use', 'saturation');

    if sat_ppm ~= 0
        rf = mr.makeSLRpulse(flip_angle_deg*pi/180, ...
            'duration',rf_duration, ...
            'timeBwProduct',fs_bw_mul*abs(sat_freq)*rf_duration, ...
            'freqPPM',sat_ppm, ...
            'use','saturation',...
            'passbandRipple',1, ...
            'stopbandRipple',1e-2, ...
            'filterType','ms', ...
            'system',sys_rf, ...
            'use', 'saturation');
    end


elseif isequal(pulse_type,'sinc')
    [rf, gz, ~] = mr.makeSincPulse(flip_angle_deg * pi/180, ...
        'system',sys_rf, ...
        'duration',rf_duration,...
        'sliceThickness',thickness, ...
        'apodization',apodization , ...
        'timeBwProduct',tbw, ...
        'use', 'saturation');

    if sat_ppm ~= 0
        [rf, gz, ~] = mr.makeSincPulse(flip_angle_deg * pi/180, ...
            'system',sys_rf, ...
            'duration',rf_duration, ...
            'freqPPM',sat_ppm, ...
            'sliceThickness',thickness, ...
            'apodization',apodization , ...
            'timeBwProduct',tbw, ...
            'use', 'saturation');

    end
elseif isequal(pulse_type,'adiabatic-hypsec')
    %values used for the work shown as an example:
    %freqPPM = -3.45;
    % thickness = 0.0015;
    % rf_duration = 0.0120;
    %bandwidth = 200;
    %n_fac = 40;
    %beta = 200;
    rf =  mr.makeAdiabaticPulse('hypsec','system',sys_rf,'freqPPM',freqPPM,'sliceThickness',thickness,'duration',rf_duration*2.5,'n_fac',n_fac,'bandwidth',bandwidth,'use','saturation','beta',beta);
end

%definition of spoilers if used in subsequent sequence:

if isequal(spoiler_type,'single')
    gz = mr.makeTrapezoid('z', sys_rf, ...
        'delay', mr.calcDuration(rf), ...
        'Area', spoiler_area);

    spoiler_area_pre = 0;
    spoiler_area_post = gz.area;

elseif isequal(spoiler_type,'double')
    if spoiler_rise_time > 0 && spoiler_flat_time > 0
        est_rise = spoiler_rise_time;
        est_flat = spoiler_flat_time;

        spoiler_pre.r = mr.makeTrapezoid('x', 'amplitude', spoiler_amp, 'riseTime', est_rise, 'flatTime', est_flat, 'system', sys_rf);
        spoiler_pre.p = mr.makeTrapezoid('y', 'amplitude', spoiler_amp, 'riseTime', est_rise, 'flatTime', est_flat, 'system', sys_rf);
        spoiler_pre.s = mr.makeTrapezoid('z', 'amplitude', spoiler_amp, 'riseTime', est_rise, 'flatTime', est_flat, 'system', sys_rf);

        delay_rf = mr.calcDuration(rf);
        spoiler_post.r = mr.makeTrapezoid('x', 'amplitude', -spoiler_amp, 'delay', delay_rf, 'riseTime', est_rise, 'flatTime', est_flat, 'system', sys_rf);
        spoiler_post.p = mr.makeTrapezoid('y', 'amplitude', -spoiler_amp, 'delay', delay_rf, 'riseTime', est_rise, 'flatTime', est_flat, 'system', sys_rf);
        spoiler_post.s = mr.makeTrapezoid('z', 'amplitude', -spoiler_amp, 'delay', delay_rf, 'riseTime', est_rise, 'flatTime', est_flat, 'system', sys_rf);
    else
        spoiler_pre.r = mr.makeTrapezoid('x', 'area', spoiler_area, 'system', sys_rf);
        spoiler_pre.p = mr.makeTrapezoid('y', 'area', spoiler_area, 'system', sys_rf);
        spoiler_pre.s = mr.makeTrapezoid('z', 'area', spoiler_area, 'system', sys_rf);

        spoiler_post.r = mr.makeTrapezoid('x', 'area', -spoiler_area, 'system', sys_rf);
        spoiler_post.p = mr.makeTrapezoid('y', 'area', -spoiler_area, 'system', sys_rf);
        spoiler_post.s = mr.makeTrapezoid('z', 'area', -spoiler_area, 'system', sys_rf);
    end

    spoiler_area_pre = spoiler_pre.r.area;
    spoiler_area_post = spoiler_post.r.area;
end

plotPulses(rf,pulse_type)

%example function for adding rf and spoilers:

function seq = add_to_seq(seq)
% Add RF and spoilers to sequence

if isequal(spoiler_type,'none')
    seq.addBlock(mr.makeDelay(0));
elseif isequal(spoiler_type,'single')
    seq.addBlock(rf, gz);

elseif isequal(spoiler_type,'double')
    seq.addBlock(spoiler_pre.r, spoiler_pre.p, spoiler_pre.s);
    seq.addBlock(rf, spoiler_post.r, spoiler_post.p, spoiler_post.s);
end

if obj.fat_sat_delay > 0
    seq.addBlock(mr.makeDelay(fat_sat_delay));
end

end

%function to simulate rf pulses:

function plotPulses(rf, pulseType)
    if nargin < 2
        pulseType = 'WURST';
    end

    [bw, f0, M_xy_sta, F1] = mr.calcRfBandwidth(rf);
    [M_z, M_xy, F2, ref_eff, ~, ~] = mr.simRf(rf, -0.5);

    labelFontSize = 18;
    titleFontSize = 20;
    legendFontSize = 16;
    lineWidth = 2;

    figure;

    subplot(2,3,1);
    % plot(F1, abs(M_xy_sta), 'LineWidth', lineWidth); hold on;
    % plot(F2, abs(M_xy), 'LineWidth', lineWidth);
    plot(F2, M_z, 'LineWidth', lineWidth); hold off;
    axis([f0-2*bw, f0+2*bw, -1.2, 1.2]);
    % legend({'M_{xySTA}','M_{xySIM}','M_{zSIM}'}, 'Location', 'southeast', 'FontSize', legendFontSize);
    xlabel('Frequency offset / Hz', 'FontSize', labelFontSize);
    ylabel('Magnetisation', 'FontSize', labelFontSize);
    title('M_{z}', 'FontSize', titleFontSize, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', labelFontSize, 'LineWidth', 1.5);

    subplot(2,3,2);
    plot(F2, real(M_xy), 'LineWidth', lineWidth); hold on;
    plot(F2, imag(M_xy), 'LineWidth', lineWidth); hold off;
    axis([f0-2*bw, f0+2*bw, -1.2, 1.2]);
    legend({'M_{xSIM}','M_{ySIM}'}, 'Location', 'southeast', 'FontSize', legendFontSize);
    xlabel('Frequency offset / Hz', 'FontSize', labelFontSize);
    ylabel('Magnetisation', 'FontSize', labelFontSize);
    title('Real & Imag parts', 'FontSize', titleFontSize, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', labelFontSize, 'LineWidth', 1.5);

    subplot(2,3,3);
    plot(F2, angle(M_xy), 'LineWidth', lineWidth);
    axis([f0-2*bw, f0+2*bw, -3.2, 3.2]);
    xlabel('Frequency offset / Hz', 'FontSize', labelFontSize);
    ylabel('Phase (radians)', 'FontSize', labelFontSize);
    legend({pulseType}, 'Location', 'southeast', 'FontSize', legendFontSize);
    title('Phase transverse magnetisation', 'FontSize', titleFontSize, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', labelFontSize, 'LineWidth', 1.5);

    subplot(2,3,4);
    plot(F2, atan2(abs(M_xy), M_z)/pi*180, 'LineWidth', lineWidth);
    axis([f0-2*bw, f0+2*bw, -5, 190]);
    xlabel('Frequency offset / Hz', 'FontSize', labelFontSize);
    ylabel('Flip angle [°]', 'FontSize', labelFontSize);
    % legend({pulseType}, 'Location', 'southeast', 'FontSize', legendFontSize);
    grid on;
    title('Achieved flip angle', 'FontSize', titleFontSize, 'FontWeight', 'bold');
    set(gca, 'FontSize', labelFontSize, 'LineWidth', 1.5);

    subplot(2,3,5);
    plot(F2, abs(ref_eff), 'LineWidth', lineWidth);
    axis([f0-2*bw, f0+2*bw, -0.1, 1.1]);
    xlabel('Frequency offset / Hz', 'FontSize', labelFontSize);
    ylabel('Efficiency', 'FontSize', labelFontSize);
    legend({pulseType}, 'Location', 'southeast', 'FontSize', legendFontSize);
    title('Refocusing efficiency', 'FontSize', titleFontSize, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', labelFontSize, 'LineWidth', 1.5);

    subplot(2,3,6);
    plot(F2, angle(ref_eff), 'LineWidth', lineWidth);
    axis([f0-2*bw, f0+2*bw, -3.2, 3.2]);
    xlabel('Frequency offset / Hz', 'FontSize', labelFontSize);
    ylabel('Phase (radians)', 'FontSize', labelFontSize);
    legend({pulseType}, 'Location', 'southeast', 'FontSize', legendFontSize);
    title('Refocusing efficiency phase', 'FontSize', titleFontSize, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', labelFontSize, 'LineWidth', 1.5);

    set(gcf, 'Position', [100 100 1400 700]);
end