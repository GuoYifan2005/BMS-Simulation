function test_balancing()
    % BMS均衡功能验证测试
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('    BMS均衡功能验证测试\n');
    fprintf('========================================\n');
    fprintf('\n');
    
    try
        % 1. 系统初始化
        fprintf('初始化电池系统...\n');
        
        % 电池参数
        cell_params = struct();
        cell_params.capacity = 14;
        cell_params.nominal_voltage = 3.5;
        cell_params.initial_soc = 0.5;
        cell_params.initial_temp = 25;
        
        % 系统配置
        sys_config = struct();
        sys_config.total_cells = 60;
        
        fprintf('系统配置: %d个电芯\n', sys_config.total_cells);
        
        % 2. 创建电池模型数组
        battery_cells = cell(1, sys_config.total_cells);
        initial_voltages = zeros(1, sys_config.total_cells);
        
        % 初始化随机数生成器（确保每次运行结果不同）
        rng('shuffle');  % 使用当前时间作为随机种子
        
        % 生成随机初始电压分布（更真实的随机性）
        % 使用正态分布生成初始电压，均值3.5V，标准差0.2V
        mean_voltage = 3.5;
        std_voltage = 0.2;  % 标准差200mV，产生更大的不均衡度
        
        for i = 1:sys_config.total_cells
            battery_cells{i} = BatteryModel(cell_params, struct('total_cells', 1));
            
            % 生成随机初始电压（正态分布）
            voltage_variation = mean_voltage + std_voltage * randn();
            
            % 确保电压在合理范围内（2.5V-4.2V）
            voltage_variation = max(2.5, min(4.2, voltage_variation));
            
            battery_cells{i}.voltage = voltage_variation;
            
            % 根据电压更新SOC（使模型更真实）
            % 使用简单的线性映射：2.5V->0%, 4.2V->100%
            estimated_soc = (voltage_variation - 2.5) / (4.2 - 2.5);
            estimated_soc = max(0, min(1, estimated_soc));
            battery_cells{i}.soc = estimated_soc;
            
            initial_voltages(i) = voltage_variation;
            
            if i == 1 || i == sys_config.total_cells || mod(i, 15) == 0
                fprintf('电芯%02d: SOC=%.1f%%, 电压=%.3fV\n', ...
                    i, battery_cells{i}.soc*100, battery_cells{i}.voltage);
            end
        end
        
        % 3. 计算初始不均衡度（使用正确的变量名）
        max_voltage_diff_initial = (max(initial_voltages) - min(initial_voltages)) * 1000;
        fprintf('初始电压不均衡度: %.1fmV\n', max_voltage_diff_initial);
        
        % 4. 创建均衡控制器
        balancing_controller = BalancingController();
        
        % 5. 运行测试
        fprintf('开始均衡测试: 120秒, 并行均衡\n');
        
        test_duration = 120;
        time_step = 1;
        
        % 预分配结果数组
        results.time = 1:test_duration;
        results.voltages = zeros(sys_config.total_cells, test_duration);
        results.max_voltage_diff = zeros(1, test_duration); % 正确的变量名
        results.balancing_active = zeros(1, test_duration);
        
        for t = 1:test_duration
            % 获取当前电压
            current_voltages = zeros(1, sys_config.total_cells);
            for i = 1:sys_config.total_cells
                current_voltages(i) = battery_cells{i}.voltage;
            end
            
            % 应用均衡控制（使用均衡前的电压）
            balancing_commands = balancing_controller.update(current_voltages, t);
            
            % 应用均衡效果
            balancing_controller.applyBalancing(battery_cells, balancing_commands, time_step);
            
            % 重新获取均衡后的电压
            voltages_after_balance = zeros(1, sys_config.total_cells);
            for i = 1:sys_config.total_cells
                voltages_after_balance(i) = battery_cells{i}.voltage;
            end
            
            % 计算均衡后的电压差（这才是最终的不均衡度）
            results.max_voltage_diff(t) = (max(voltages_after_balance) - min(voltages_after_balance)) * 1000;
            
            % 记录均衡后的不均衡度到控制器（用于图表显示，单位：mV）
            balancing_controller.recordAfterBalance(results.max_voltage_diff(t));
            
            % 记录结果（记录均衡后的电压）
            results.voltages(:, t) = voltages_after_balance';
            results.balancing_active(t) = sum(balancing_commands > 0);
            
            % 进度显示
            if mod(t, 30) == 0 || t <= 5
                fprintf('时间 %03ds: 压差=%6.1fmV, 均衡中=%d个电芯\n', ...
                    t, results.max_voltage_diff(t), results.balancing_active(t));
            end
            
            % 提前达标检查
            if results.max_voltage_diff(t) <= 100 && t < test_duration/2
                fprintf('🎯 提前达标! 在%d秒达到目标\n', t);
                break;
            end
        end
        
        % 6. 生成测试报告
        generate_test_report(results, max_voltage_diff_initial, balancing_controller);
        
        fprintf('=== 均衡测试完成 ===\n');
        
    catch ME
        fprintf('错误: %s\n', ME.message);
        fprintf('在文件: %s, 行: %d\n', ME.stack(1).file, ME.stack(1).line);
    end
end

function generate_test_report(results, initial_diff, balancing_controller)
    % 生成测试报告
    
    actual_samples = length(results.time);
    final_diff = results.max_voltage_diff(actual_samples);
    improvement = (initial_diff - final_diff) / initial_diff * 100;
    avg_parallel = mean(results.balancing_active(1:actual_samples));
    
    fprintf('\n=== 均衡测试报告 ===\n');
    fprintf('测试配置: %d个电芯, %d秒测试\n', size(results.voltages, 1), actual_samples);
    fprintf('初始电压不均衡度: %.1fmV\n', initial_diff);
    fprintf('最终电压不均衡度: %.1fmV\n', final_diff);
    fprintf('改善程度: %.1f%%\n', improvement);
    fprintf('平均并行均衡: %.1f个电芯/次\n', avg_parallel);
    fprintf('测试时长: %d秒\n', actual_samples);
    
    % 性能评估
    if final_diff <= 100
        fprintf('🎯 达标状态: ✅ 完全达标 (压差%.1fmV ≤ 100mV)\n', final_diff);
    else
        fprintf('🎯 达标状态: ⚠️ 部分达标 (压差%.1fmV > 100mV)\n', final_diff);
    end
    
    % 绘制结果
    balancing_controller.plotResults();
end
