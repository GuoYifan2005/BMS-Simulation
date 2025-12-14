classdef BalancingController < handle
    % 高性能均衡控制器 
   
    properties
        % 均衡参数
        balancing_threshold = 0.05;        % 50mV启动阈值
        balancing_current = 0.2;          % 200mA均衡电流
        max_parallel_balance = 3;         % 最大并行均衡数
        adaptive_mode = true;             % 自适应模式
        
        % 性能监控
        imbalance_history = [];          % 均衡前的不均衡度历史
        imbalance_history_after = [];   % 均衡后的不均衡度历史
        balancing_history = [];
        performance_metrics = struct();
        
        % 状态变量
        last_balance_time = 0;
        balance_count = 0;
    end
    
    methods
        function obj = BalancingController()
            % 构造函数
            fprintf('初始化高性能均衡控制器...\n');
            fprintf('均衡阈值: %.0fmV, 并行数: %d, 均衡电流: %.0fmA\n', ...
                obj.balancing_threshold*1000, obj.max_parallel_balance, obj.balancing_current*1000);
        end
        
        function balancing_commands = update(obj, cell_voltages, current_time)
            % 优化版均衡控制 - 支持并行均衡
            
            % 输入验证
            if isempty(cell_voltages)
                balancing_commands = [];
                return;
            end
            
            % 计算电压统计
            avg_voltage = mean(cell_voltages);
            max_voltage = max(cell_voltages);
            min_voltage = min(cell_voltages);
            max_voltage_diff = (max_voltage - min_voltage); 
            
            % 记录不均衡度（转换为mV）
            obj.imbalance_history(end+1) = max_voltage_diff * 1000;
            
            % 初始化均衡命令
            balancing_commands = zeros(1, length(cell_voltages));
            
            % 检查是否需要进行均衡
            if max_voltage_diff > obj.balancing_threshold
                % 找到需要均衡的电芯（电压高于平均值的）
                high_voltage_indices = find(cell_voltages > avg_voltage + obj.balancing_threshold/2);
                
                if ~isempty(high_voltage_indices)
                    % 限制最大并行均衡数
                    obj.balance_count = min(length(high_voltage_indices), obj.max_parallel_balance);
                    
                    % 选择电压最高的几个电芯
                    [~, sort_idx] = sort(cell_voltages(high_voltage_indices), 'descend');
                    active_cells = high_voltage_indices(sort_idx(1:obj.balance_count));
                    
                    % 设置均衡命令
                    for i = 1:length(active_cells)
                        cell_idx = active_cells(i);
                        voltage_excess = cell_voltages(cell_idx) - avg_voltage;
                        
                        % 自适应均衡电流
                        adaptive_current = obj.balancing_current * (1 + voltage_excess * 5);
                        balancing_commands(cell_idx) = min(adaptive_current, 0.3); % 限制最大300mA
                    end
                    
                    % 性能记录
                    obj.balance_count = obj.balance_count + 1;
                    obj.last_balance_time = current_time;
                    
                    fprintf('均衡激活: %d个电芯, 压差: %.1fmV\n', ...
                        obj.balance_count, max_voltage_diff*1000);
                end
            end
            
            % 记录均衡活动
            obj.balancing_history(end+1) = sum(balancing_commands > 0);
        end
        
        function applyBalancing(~, battery_cells, commands, time_step)
            % 应用均衡到电池模型数组
            
            for i = 1:length(commands)
                if commands(i) > 0 && i <= length(battery_cells)
                    % 模拟均衡能耗
                    delta_soc = commands(i) * time_step / 3600 / battery_cells{i}.capacity;
                    battery_cells{i}.soc = max(0, battery_cells{i}.soc - delta_soc);
                    
                    % 更新电压（基于SOC）
                    ocv = battery_cells{i}.calculateOCV(battery_cells{i}.soc, battery_cells{i}.temperature);
                    battery_cells{i}.voltage = ocv;
                end
            end
        end
        
        function recordAfterBalance(obj, imbalance_after_mv)
            % 记录均衡后的不均衡度（单位：mV）
            obj.imbalance_history_after(end+1) = imbalance_after_mv;
        end
        
        function performance = getPerformance(obj)
            % 获取性能统计（优先使用均衡后的数据）
            performance = struct();
            
            % 优先使用均衡后的历史数据（单位：mV）
            if ~isempty(obj.imbalance_history_after)
                performance.initial_imbalance = obj.imbalance_history_after(1);
                performance.final_imbalance = obj.imbalance_history_after(end);
                performance.improvement = (performance.initial_imbalance - performance.final_imbalance) / performance.initial_imbalance * 100;
            elseif ~isempty(obj.imbalance_history)
                % 如果没有均衡后的数据，使用均衡前的数据
                performance.initial_imbalance = obj.imbalance_history(1);
                performance.final_imbalance = obj.imbalance_history(end);
                performance.improvement = (performance.initial_imbalance - performance.final_imbalance) / performance.initial_imbalance * 100;
            else
                performance.initial_imbalance = 0;
                performance.final_imbalance = 0;
                performance.improvement = 0;
            end
            
            if ~isempty(obj.balancing_history)
                performance.avg_balance_active = mean(obj.balancing_history);
                performance.total_balance_events = sum(obj.balancing_history > 0);
            else
                performance.avg_balance_active = 0;
                performance.total_balance_events = 0;
            end
        end
        
        function plotResults(obj)
            % 绘制优化后的均衡结果（使用均衡后的数据）
            % 优先使用均衡后的历史数据，如果没有则使用均衡前的数据
            if ~isempty(obj.imbalance_history_after)
                plot_data = obj.imbalance_history_after;
            elseif length(obj.imbalance_history) >= 2
                plot_data = obj.imbalance_history;
            else
                fprintf('数据不足，无法绘制图表\n');
                return;
            end
            
            if length(plot_data) < 2
                fprintf('数据不足，无法绘制图表\n');
                return;
            end
            
            figure('Position', [100, 100, 1200, 500], 'Name', 'BMS均衡功能验证', 'NumberTitle', 'off');
            
            % 性能摘要（用于标题）
            perf = obj.getPerformance();
            
            % 设置总标题
            sgtitle(sprintf('BMS均衡功能验证 - 改善%.1f%%, 最终不均衡度%.1fmV (目标≤100mV)', ...
                perf.improvement, perf.final_imbalance), 'FontSize', 16, 'FontWeight', 'bold');
            
            subplot(1,2,1);
            plot(plot_data, 'b-', 'LineWidth', 2);
            hold on;
            plot([1, length(plot_data)], [50, 50], 'r--', 'LineWidth', 1, 'DisplayName', '50mV目标');
            plot([1, length(plot_data)], [100, 100], 'g--', 'LineWidth', 1, 'DisplayName', '100mV目标');
            xlabel('时间 (s)'); 
            ylabel('电压不均衡度 (mV)');
            title('电压一致性优化', 'FontSize', 12, 'FontWeight', 'bold'); 
            legend('show', 'Location', 'best'); 
            grid on;
            
            subplot(1,2,2);
            stem(obj.balancing_history, 'filled', 'MarkerSize', 3);
            xlabel('时间 (s)'); 
            ylabel('均衡电芯数量');
            title(sprintf('均衡活动 (平均: %.1f个/次)', mean(obj.balancing_history)), 'FontSize', 12, 'FontWeight', 'bold');
            ylim([0, obj.max_parallel_balance+1]);
            grid on;
        end
    end
end