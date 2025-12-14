classdef SOCEstimator < handle
    % SOC估算器类 
  
    properties
        % EKF参数
        soc_estimate double
        error_covariance double
        process_noise double
        measurement_noise double
        
        % 电池参数
        capacity double
        internal_resistance double
        
        % 性能统计
        estimation_history double
        true_soc_history double
        error_history double
        total_samples double
    end
    
    methods
        function obj = SOCEstimator(initial_soc, battery_capacity)
            % 构造函数 - 完全修复版本
            
            fprintf('初始化SOC估算器...\n');
            
            % 参数验证（不使用外部ensureDouble函数）
            if nargin < 1
                initial_soc = 0.5;
                fprintf('使用默认初始SOC: 50%%\n');
            else
                initial_soc = obj.validateParameter(initial_soc, 'initial_soc', 0.5, 0, 1);
            end
            
            if nargin < 2
                battery_capacity = 14;
                fprintf('使用默认电池容量: 14Ah\n');
            else
                battery_capacity = obj.validateParameter(battery_capacity, 'battery_capacity', 14, 1, 1000);
            end
            
            % 初始化EKF参数
            obj.soc_estimate = initial_soc;
            obj.error_covariance = 0.01;
            obj.process_noise = 1e-6;
            obj.measurement_noise = 1e-4;
            
            % 电池参数
            obj.capacity = battery_capacity;
            obj.internal_resistance = 0.0018;
            
            % 初始化历史记录
            obj.estimation_history = [];
            obj.true_soc_history = [];
            obj.error_history = [];
            obj.total_samples = 0;
            
            fprintf('SOC估算器创建成功: 初始SOC=%.1f%%, 电池容量=%.1fAh\n', ...
                initial_soc*100, battery_capacity);
        end
        
        function value = validateParameter(~, value, param_name, default_value, min_val, max_val)
            % 内联参数验证函数 - 替换ensureDouble
            % 输入验证
            if nargin < 6
                max_val = inf;
            end
            if nargin < 5
                min_val = -inf;
            end
            if nargin < 4
                default_value = 0;
            end
            if nargin < 3
                param_name = '参数';
            end
            
            % 类型检查
            if ~isnumeric(value)
                value = default_value;
            else
                % 转换为双精度
                value = double(value);
                
                % 范围检查，超界直接夹紧，不再频繁告警
                if value < min_val
                    value = min_val;
                elseif value > max_val
                    value = max_val;
                end
            end
        end
        
        function soc = update(obj, current, voltage, temperature, delta_time, true_soc)
            % SOC估算更新 (EKF算法)
            
            % 输入参数验证
            current = obj.validateParameter(current, 'current', 0);
            voltage = obj.validateParameter(voltage, 'voltage', 3.5);
            temperature = obj.validateParameter(temperature, 'temperature', 25);
            delta_time = obj.validateParameter(delta_time, 'delta_time', 1, 0.001, 3600);
            
            if nargin >= 6
                true_soc = obj.validateParameter(true_soc, 'true_soc', obj.soc_estimate, 0, 1);
            else
                true_soc = obj.soc_estimate;
            end
            
            try
                % 预测步骤 (安时积分)
                soc_predicted = obj.soc_estimate - (current * delta_time / 3600) / obj.capacity;
                covariance_predicted = obj.error_covariance + obj.process_noise;
                
                % 观测预测
                [ocv_predicted, sensitivity] = obj.predictOCV(soc_predicted, temperature);
                voltage_predicted = ocv_predicted - current * obj.internal_resistance;
                
                % 卡尔曼增益
                innovation_covariance = sensitivity * covariance_predicted * sensitivity + obj.measurement_noise;
                kalman_gain = covariance_predicted * sensitivity / innovation_covariance;
                
                % 更新步骤
                innovation = voltage - voltage_predicted;
                obj.soc_estimate = soc_predicted + kalman_gain * innovation;
                obj.error_covariance = (1 - kalman_gain * sensitivity) * covariance_predicted;
                
                % 限制SOC范围，静默夹紧
                obj.soc_estimate = max(0, min(1, obj.soc_estimate));
                
                % 记录数据
                obj.estimation_history(end+1) = obj.soc_estimate;
                obj.true_soc_history(end+1) = true_soc;
                obj.error_history(end+1) = innovation;
                obj.total_samples = obj.total_samples + 1;
                
                soc = obj.soc_estimate;
                
            catch ME
                fprintf('EKF算法错误: %s，使用安时积分\n', ME.message);
                % 降级到安时积分
                soc_predicted = obj.soc_estimate - (current * delta_time / 3600) / obj.capacity;
                obj.soc_estimate = max(0, min(1, soc_predicted));
                soc = obj.soc_estimate;
            end
        end
        
        function [ocv, gradient] = predictOCV(obj, soc, temp)
            % OCV预测函数
            
            % 输入验证
            soc = obj.validateParameter(soc, 'soc', 0.5, 0, 1);
            temp = obj.validateParameter(temp, 'temp', 25, -20, 80);
            
            try
                % OCV-SOC曲线数据点
                soc_points = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
                ocv_points = [2.5000, 2.8922, 3.0643, 3.2100, 3.3345, 3.4605, 3.60165, 3.69465, 3.8218, 3.88735, 4.1385];
                
                % 插值计算
                ocv = interp1(soc_points, ocv_points, soc, 'pchip', 'extrap');
                
                % 数值梯度计算
                if soc > 0.01 && soc < 0.99
                    soc_delta = 0.01;
                    ocv_plus = interp1(soc_points, ocv_points, soc+soc_delta, 'linear', 'extrap');
                    ocv_minus = interp1(soc_points, ocv_points, soc-soc_delta, 'linear', 'extrap');
                    gradient = (ocv_plus - ocv_minus) / (2 * soc_delta);
                else
                    gradient = 0.01; % 边界保护
                end
                
                % 温度补偿
                temp_compensation = (temp - 25) * 0.0003;
                ocv = ocv + temp_compensation;
                
            catch ME
                fprintf('OCV预测错误: %s，使用线性近似\n', ME.message);
                % 降级到线性近似
                ocv = 2.5 + soc * (4.2 - 2.5);
                gradient = 1.7;
            end
        end
        
        function accuracy = getAccuracy(obj)
            % 计算SOC估算精度
            if obj.total_samples > 10
                soc_errors = abs(obj.estimation_history - obj.true_soc_history) * 100;
                max_error = max(soc_errors);
                avg_error = mean(soc_errors);
                
                fprintf('SOC估算精度: 最大误差=%.2f%%, 平均误差=%.2f%%\n', max_error, avg_error);
                accuracy = 100 - avg_error;
            else
                accuracy = 100;
                fprintf('样本数不足，无法计算准确精度\n');
            end
        end
        
        function plotResults(obj)
            % 绘制SOC估算结果
            if obj.total_samples < 2
                fprintf('数据不足，无法绘制图表\n');
                return;
            end
            
            figure('Position', [100, 100, 800, 400], 'Name', 'SOC估算性能分析');
            
            subplot(1,2,1);
            time_axis = 1:obj.total_samples;
            plot(time_axis, obj.true_soc_history*100, 'b-', 'LineWidth', 2, 'DisplayName', '真实SOC');
            hold on;
            plot(time_axis, obj.estimation_history*100, 'r--', 'LineWidth', 2, 'DisplayName', '估算SOC');
            xlabel('样本点'); ylabel('SOC (%)'); 
            title('SOC估算对比'); 
            legend('show'); 
            grid on;
            
            subplot(1,2,2);
            plot(time_axis, abs(obj.error_history)*1000, 'g-', 'LineWidth', 2);
            xlabel('样本点'); ylabel('估算误差 (mV)');
            title('SOC估算误差'); 
            grid on;
            
            % 性能指标
            max_error = max(abs(obj.error_history)) * 100;
            avg_error = mean(abs(obj.error_history)) * 100;
            sgtitle(sprintf('SOC估算性能 (最大误差: %.2f%%)', max_error));
        end
    end
end