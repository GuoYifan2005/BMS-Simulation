function results = simulateBMS(battery_cells, soc_estimator, balancing_controller, thermal_warning, config)
    % BMS系统仿真函数（20S3P → 60节电芯，含采样误差与均衡、热预警闭环）
    %
    % 输入可为空；若为空则使用默认配置自动创建。
    
    fprintf('开始BMS系统仿真（20S3P, 60 cells）...\n');
    
    %% 参数与对象初始化
    if nargin < 5 || isempty(config);          config = struct(); end
    if ~isfield(config, 'total_cells');        config.total_cells = 60; end  % 20S3P
    if ~isfield(config, 'simulation_time');    config.simulation_time = 1800; end % 30分钟
    if ~isfield(config, 'time_step');          config.time_step = 1; end
    if ~isfield(config, 'ambient_temp');       config.ambient_temp = 25; end
    if ~isfield(config, 'discharge_current');  config.discharge_current = -168; end % 42Ah(14Ah*3P)*4C
    if ~isfield(config, 'h_conv');             config.h_conv = 8; end % W/(m^2*K) 可调对流系数
    
    total_cells     = config.total_cells;
    n_parallel      = 3;
    n_series        = total_cells / n_parallel;
    simulation_time = config.simulation_time;
    time_step       = config.time_step;
    ambient_temp    = config.ambient_temp;
    discharge_current = config.discharge_current;
    
    % 对象缺省创建
    if nargin < 1 || isempty(battery_cells)
        cell_params = struct('capacity', 14, 'nominal_voltage', 3.5, ...
                             'initial_soc', 0.55, 'initial_temp', ambient_temp, ...
                             'specific_heat', 1160, 'k_in_plane', 18, 'k_through', 1.3, ...
                             'dimensions_mm', [10, 60, 100]);
        battery_cells = cell(1, total_cells);
        for i = 1:total_cells
            battery_cells{i} = BatteryModel(cell_params, struct('total_cells', 1));
            % 为不均衡与温差创造初始扰动
            battery_cells{i}.soc = max(0, min(1, cell_params.initial_soc + (rand()-0.5)*0.08));
            battery_cells{i}.temperature = ambient_temp + (rand()-0.5)*2;
            battery_cells{i}.voltage = battery_cells{i}.calculateOCV(battery_cells{i}.soc, battery_cells{i}.temperature);
        end
    end
    
    if nargin < 2 || isempty(soc_estimator)
        soc_estimator = SOCEstimator(0.55, 14*3); % pack 容量 3P
    end
    if nargin < 3 || isempty(balancing_controller)
        balancing_controller = BalancingController();
    end
    if nargin < 4 || isempty(thermal_warning)
        thermal_warning = ThermalRunawayWarning();
    end
    
    %% 结果预分配
    results.time             = 1:simulation_time;
    results.soc_estimated    = zeros(1, simulation_time);
    results.soc_true         = zeros(1, simulation_time);
    results.voltages         = zeros(simulation_time, total_cells);
    results.temperatures     = zeros(simulation_time, total_cells);
    results.pack_voltage     = zeros(1, simulation_time);
    results.warning_level    = zeros(1, simulation_time);
    results.balancing_active = zeros(1, simulation_time);
    results.max_temp         = zeros(1, simulation_time);
    results.max_voltage_diff = zeros(1, simulation_time);
    results.temp_spread      = zeros(1, simulation_time);
    results.measurement_meta = [];
    
    %% 主仿真循环
    for t = 1:simulation_time
        try
            % 1) 更新每个电芯真实状态
            ideal_voltages = zeros(1, total_cells);
            ideal_temps    = zeros(1, total_cells);
            ideal_socs     = zeros(1, total_cells);
            
            cell_current = discharge_current / n_parallel; % 3P 均分电流
            for i = 1:total_cells
                battery_cells{i}.update(cell_current, time_step, ambient_temp);
                ideal_voltages(i) = battery_cells{i}.voltage;
                ideal_temps(i)    = battery_cells{i}.temperature;
                ideal_socs(i)     = battery_cells{i}.soc;
            end
            
            % 2) 采样误差模型（±1% FSR 验证用）
            meas = applyMeasurementModel(ideal_voltages, ideal_temps, discharge_current);
            
            % 3) SOC 估算（用测量的 pack 电压与温度）
            volt_mat_meas = reshape(meas.voltages, n_parallel, n_series); % 3P -> 对每串取均值
            string_voltage_meas = mean(volt_mat_meas, 1);
            pack_voltage_meas = sum(string_voltage_meas);
            true_soc = mean(ideal_socs);
            estimated_soc = soc_estimator.update(meas.current, pack_voltage_meas, ...
                                                 mean(meas.temperatures), time_step, true_soc);
            
            % 4) 均衡控制（基于测得单体电压）
            balancing_commands = balancing_controller.update(meas.voltages, t);
            balancing_controller.applyBalancing(battery_cells, balancing_commands, time_step);
            
            % 5) 热失控预警（使用测量值）
            warning_level = thermal_warning.checkWarning(meas.voltages, meas.temperatures, meas.current, time_step);
            
            % 6) 结果记录（使用真实值评估效果）
            results.soc_estimated(t)    = estimated_soc;
            results.soc_true(t)         = true_soc;
            results.voltages(t, :)      = meas.voltages;
            results.temperatures(t, :)  = meas.temperatures;
            volt_mat_true = reshape(ideal_voltages, n_parallel, n_series);
            string_voltage_true = mean(volt_mat_true, 1);
            results.pack_voltage(t)     = sum(string_voltage_true);
            results.warning_level(t)    = warning_level;
            results.balancing_active(t) = sum(balancing_commands > 0);
            results.max_temp(t)         = max(meas.temperatures);
            results.max_voltage_diff(t) = max(meas.voltages) - min(meas.voltages);
            results.temp_spread(t)      = max(meas.temperatures) - min(meas.temperatures);
            
            if mod(t, 300) == 0
                fprintf('进度 %4d/%4d s | SOC估计 %.1f%% | ΔV=%.1fmV | Tmax=%.1f℃ | 预警=%d\n', ...
                    t, simulation_time, estimated_soc*100, results.max_voltage_diff(t)*1000, ...
                    results.max_temp(t), warning_level);
            end
            
        catch ME
            fprintf('仿真错误在时间步 %d: %s\n', t, ME.message);
            break;
        end
    end
    
    fprintf('BMS系统仿真完成\n');
    
    % 合规性快速检查（按表2要求）
    compliance = struct();
    compliance.max_pack_voltage = max(results.pack_voltage);
    compliance.min_pack_voltage = min(results.pack_voltage);
    compliance.max_temp = max(results.max_temp);
    compliance.temp_rise = compliance.max_temp - ambient_temp;
    compliance.temp_spread = max(results.max_temp) - min(results.max_temp); % 近似：用记录的最高温差近似内部温差
    
    compliance.voltage_ok = (compliance.max_pack_voltage <= 90) && (compliance.min_pack_voltage >= 50);
    compliance.temp_ok = (compliance.max_temp <= 60) && (compliance.temp_rise <= 35);
    compliance.temp_spread_ok = (compliance.temp_spread <= 8);
    
    fprintf('合规性检查: Umax=%.2fV (<=90V:%d) | Umin=%.2fV (>=50V:%d) | Tmax=%.1f℃ ΔT=%.1f℃ (<=35:%d) | 内部温差≈%.1f℃ (<=8:%d)\n', ...
        compliance.max_pack_voltage, compliance.voltage_ok, ...
        compliance.min_pack_voltage, compliance.voltage_ok, ...
        compliance.max_temp, compliance.temp_rise, compliance.temp_ok, ...
        compliance.temp_spread, compliance.temp_spread_ok);
    
    results.compliance = compliance;
end

%% 采样误差模型：注入增益/偏移/量化/噪声，符合±1%%FSR设定
function meas = applyMeasurementModel(voltages, temperatures, current_true)
    % 电压（单体）满量程假定 1.7V (2.5~4.2V)
    cell_fsr = 4.2 - 2.5;
    gain_error_v   = 1 + (rand()-0.5)*0.002;          % ±0.1% 增益
    offset_error_v = (rand()-0.5)*cell_fsr*0.002;     % ±0.2% FSR 偏移
    adc_res_v      = cell_fsr / 4096;                 % 12bit 量化
    noise_v        = cell_fsr * 0.0005;               % 0.05% FSR 噪声
    
    meas_volt = voltages * gain_error_v + offset_error_v;
    meas_volt = round(meas_volt / adc_res_v) * adc_res_v;
    meas_volt = meas_volt + noise_v * randn(size(meas_volt));
    
    % 温度测量噪声（简化）
    meas_temp = temperatures + 0.2*randn(size(temperatures));
    
    % 电流满量程假定 ±200A（> 4C 需求），1%FSR=2A
    current_fsr = 400;
    gain_error_c   = 1 + (rand()-0.5)*0.002;
    offset_error_c = (rand()-0.5)*current_fsr*0.002;
    adc_res_c      = current_fsr / 4096;
    noise_c        = current_fsr * 0.0005;
    
    meas_current = current_true * gain_error_c + offset_error_c;
    meas_current = round(meas_current / adc_res_c) * adc_res_c;
    meas_current = meas_current + noise_c * randn();
    
    meas = struct('voltages', meas_volt, 'temperatures', meas_temp, 'current', meas_current);
    meas.meta = struct('cell_fsr', cell_fsr, 'gain_error_v', gain_error_v, 'offset_error_v', offset_error_v, ...
                       'adc_res_v', adc_res_v, 'noise_v', noise_v, 'current_fsr', current_fsr, ...
                       'gain_error_c', gain_error_c, 'offset_error_c', offset_error_c, ...
                       'adc_res_c', adc_res_c, 'noise_c', noise_c);
end