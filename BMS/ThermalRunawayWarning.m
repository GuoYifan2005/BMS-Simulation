classdef ThermalRunawayWarning < handle
    % 热失控预警类 - 实现多级安全预警
    
    properties
        % 预警阈值
        temp_threshold1 double   % 一级预警
        temp_threshold2 double   % 二级预警  
        temp_threshold3 double   % 三级预警
        
        temp_rise_rate_threshold double
        voltage_drop_threshold double
        
        % 状态记录
        warning_level_history double
        warning_history cell
        temp_history double
        voltage_history double
        
        % 去抖与滑窗
        temp_rise_window double
        debounce_steps double
        effective_level double
        pending_level double
        pending_count double
    end
    
    methods
        function obj = ThermalRunawayWarning()
            % 构造函数
            obj.temp_threshold1 = 45;     % 一级预警
            obj.temp_threshold2 = 60;     % 二级预警
            obj.temp_threshold3 = 80;     % 三级预警
            
            obj.temp_rise_rate_threshold = 2;  % ℃/s
            obj.voltage_drop_threshold = 0.1;  % V
            
            obj.warning_level_history = [];
            obj.warning_history = {};
            obj.temp_history = [];
            obj.voltage_history = [];
            
            % 去抖参数
            obj.temp_rise_window = 5;     % 温升率滑窗（秒）
            obj.debounce_steps = 2;       % 预警级别需持续的步数
            obj.effective_level = 0;
            obj.pending_level = 0;
            obj.pending_count = 0;
        end
        
        function warning_level = checkWarning(obj, voltages, temperatures, ~, time_step)
            % 热失控预警检查
            
            max_temp = max(temperatures);
            avg_voltage = mean(voltages);
            
            % 记录历史数据
            obj.temp_history(end+1) = max_temp;
            obj.voltage_history(end+1) = avg_voltage;
            
            % 计算温升速率
            hist_len = length(obj.temp_history);
            if hist_len > 1
                % 滑窗平均温升率，降低噪声
                win = min(obj.temp_rise_window, hist_len-1);
                temp_rise_rate = (obj.temp_history(end) - obj.temp_history(end-win)) / (win * time_step);
            else
                temp_rise_rate = 0;
            end
            
            % 计算电压稳定性
            if length(obj.voltage_history) > 1
                voltage_drop = obj.voltage_history(end-1) - avg_voltage;
            else
                voltage_drop = 0;
            end
            
            % 多级预警逻辑
            if max_temp > obj.temp_threshold3 || ...
               (temp_rise_rate > obj.temp_rise_rate_threshold && voltage_drop > obj.voltage_drop_threshold)
                warning_level = 3; % 紧急关断
                warning_msg = '三级预警: 热失控风险';
                
            elseif max_temp > obj.temp_threshold2 && temp_rise_rate > 1
                warning_level = 2; % 降功率运行
                warning_msg = '二级预警: 高温告警';
                
            elseif max_temp > obj.temp_threshold1 || voltage_drop > obj.voltage_drop_threshold
                warning_level = 1; % 预警提示
                warning_msg = '一级预警: 参数异常';
                
            else
                warning_level = 0; % 正常状态
                warning_msg = '系统正常';
            end
            
            % 去抖：级别需持续 debounce_steps 才生效
            if warning_level ~= obj.pending_level
                obj.pending_level = warning_level;
                obj.pending_count = 1;
            else
                obj.pending_count = obj.pending_count + 1;
            end
            
            if obj.pending_count >= obj.debounce_steps
                obj.effective_level = obj.pending_level;
            end
            
            warning_level = obj.effective_level;
            
            % 记录预警信息
            obj.warning_level_history(end+1) = warning_level;
            if warning_level > 0
                warning_record = struct();
                warning_record.time = length(obj.warning_level_history);
                warning_record.level = warning_level;
                warning_record.message = warning_msg;
                warning_record.temperature = max_temp;
                warning_record.voltage_drop = voltage_drop;
                
                obj.warning_history{end+1} = warning_record;
                
                if warning_level >= 2
                    fprintf('安全警报: %s, 温度: %.1f℃, 电压下降: %.3fV\n', ...
                        warning_msg, max_temp, voltage_drop);
                end
            end
        end
        
        function plotResults(obj)
            % 绘制预警结果
            if isempty(obj.warning_level_history)
                fprintf('无预警事件发生\n');
                return;
            end
            
            figure('Position', [100, 100, 800, 600]);
            
            subplot(2,1,1);
            plot(obj.temp_history, 'r-', 'LineWidth', 2);
            hold on;
            plot([1, length(obj.temp_history)], [obj.temp_threshold1, obj.temp_threshold1], 'g--', 'DisplayName', '一级预警线');
            plot([1, length(obj.temp_history)], [obj.temp_threshold2, obj.temp_threshold2], 'y--', 'DisplayName', '二级预警线');
            plot([1, length(obj.temp_history)], [obj.temp_threshold3, obj.temp_threshold3], 'r--', 'DisplayName', '三级预警线');
            xlabel('时间 (s)'); ylabel('温度 (℃)');
            title('温度监控'); legend; grid on;
            
            subplot(2,1,2);
            stem(obj.warning_level_history, 'filled', 'LineWidth', 2);
            xlabel('时间 (s)'); ylabel('预警等级');
            title('热失控预警记录'); 
            ylim([-0.5, 3.5]); grid on;
            
            sgtitle('热失控预警系统分析');
        end
        
        function stats = getStatistics(obj)
            % 获取预警统计
            stats = struct();
            if isempty(obj.warning_level_history)
                stats.total_warnings = 0;
                stats.level_distribution = zeros(1, 4);
            else
                stats.total_warnings = sum(obj.warning_level_history > 0);
                stats.level_distribution = histcounts(obj.warning_level_history, -0.5:1:3.5);
            end
        end
    end
end