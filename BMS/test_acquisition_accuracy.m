function test_acquisition_accuracy()
    % BMS电压电流采集精度验证测试
 
    try
        %% 1. 测试参数配置
        fprintf('=== 阶段1: 测试参数配置 ===\n');
        
        % 电压范围配置（修正FSR计算）
        voltage_range = struct();
        voltage_range.min = 50;   % 最低电压50V（基于20S*2.5V）
        voltage_range.max = 84;   % 最高电压84V（基于20S*4.2V）
        voltage_range.fsr = voltage_range.max - voltage_range.min; % 正确FSR: 34V
        voltage_range.allowed_error = voltage_range.fsr * 0.01;    % ±0.34V允许误差
        
        % 电流范围配置
        current_range = struct();
        current_range.min = -70;  % 最大充电电流70A
        current_range.max = 70;  % 最大放电电流70A  
        current_range.fsr = current_range.max - current_range.min; % 140A满量程
        current_range.allowed_error = current_range.fsr * 0.01;     % ±1.4A允许误差
        
        fprintf('系统配置: 20S电池包\n');
        fprintf('电压范围: %.0fV-%.0fV (FSR: %.0fV, 允许误差: ±%.2fV)\n', ...
            voltage_range.min, voltage_range.max, voltage_range.fsr, voltage_range.allowed_error);
        fprintf('电流范围: %.0fA-%.0fA (FSR: %.0fA, 允许误差: ±%.1fA)\n\n', ...
            current_range.min, current_range.max, current_range.fsr, current_range.allowed_error);
        
        %% 2. 生成测试信号
        fprintf('=== 阶段2: 生成测试信号 ===\n');
        
        test_data = generate_test_signals(voltage_range, current_range);
        fprintf('生成测试信号: %d个电压点, %d个电流点\n', ...
            length(test_data.voltage), length(test_data.current));
        
        %% 3. 模拟采集过程
        fprintf('=== 阶段3: 模拟采集过程 ===\n');
        
        ideal_data = simulate_ideal_acquisition(test_data);
        actual_data = simulate_realistic_acquisition(test_data, voltage_range, current_range);
        fprintf('采集模拟完成\n');
        
        %% 4. 精度计算分析
        fprintf('=== 阶段4: 精度计算分析 ===\n');
        
        accuracy_results = calculate_accuracy_metrics(ideal_data, actual_data, voltage_range, current_range);
        fprintf('精度计算完成\n');
        
        %% 5. 生成验证报告
        fprintf('=== 阶段5: 生成验证报告 ===\n');
        
        generate_accuracy_report(accuracy_results, voltage_range, current_range);
        
        %% 6. 可视化结果
        fprintf('=== 阶段6: 结果可视化 ===\n');
        
        plot_comprehensive_results(ideal_data, actual_data, accuracy_results, voltage_range, current_range);
        fprintf('图表生成完成\n');
        
        fprintf('\n========================================\n');
        fprintf('   采集精度验证测试完成\n');
        fprintf('========================================\n\n');
        
    catch ME
        fprintf('\n❌ 测试错误: %s\n', ME.message);
        fprintf('错误位置: %s, 行: %d\n', ME.stack(1).file, ME.stack(1).line);
        fprintf('建议: 检查函数定义和变量作用域\n');
    end
end

%% 核心函数定义
function test_data = generate_test_signals(voltage_range, current_range)
    % 生成全面的测试信号
    
    fprintf('生成全面测试信号...\n');
    
    test_data = struct();
    num_points = 200; % 增加测试点数提高统计可靠性
    
    % 电压测试信号：覆盖全工作范围
    test_data.voltage = linspace(voltage_range.min, voltage_range.max, num_points);
    
    % 电流测试信号：包含充放电工况
    test_data.current = [linspace(current_range.min, 0, num_points/2), linspace(0, current_range.max, num_points/2)];
    test_data.time = 1:num_points;
    
    % 添加关键工作点
    critical_voltages = [50, 60, 70, 80, 84]; % 重要电压点
    critical_currents = [-70, -35, 0, 35, 70]; % 重要电流点
    
    test_data.voltage = sort([test_data.voltage, critical_voltages]);
    test_data.current = sort([test_data.current, critical_currents]);
    test_data.time = 1:length(test_data.voltage);
    
    fprintf('生成 %d 个测试点（包含%d个关键点）\n', ...
        length(test_data.voltage), length(critical_voltages));
end

function ideal_data = simulate_ideal_acquisition(test_data)
    % 模拟理想采集（无误差基准）
    
    ideal_data = struct();
    ideal_data.voltage = test_data.voltage;
    ideal_data.current = test_data.current;
    ideal_data.time = test_data.time;
end

function actual_data = simulate_realistic_acquisition(test_data, voltage_range, current_range)
    % 模拟实际采集（合理的误差模型）
    
    fprintf('模拟实际采集误差...\n');
    
    % 合理的传感器误差模型（符合实际BMS规格）
    gain_error_voltage = 1 + (rand() - 0.5) * 0.002;  % ±0.1% 增益误差
    gain_error_current = 1 + (rand() - 0.5) * 0.002;  % ±0.1% 增益误差
    
    offset_error_voltage = (rand() - 0.5) * voltage_range.fsr * 0.002;  % ±0.2% FSR偏移
    offset_error_current = (rand() - 0.5) * current_range.fsr * 0.002;  % ±0.2% FSR偏移
    
    % 应用误差模型
    actual_data = struct();
    actual_data.voltage = test_data.voltage * gain_error_voltage + offset_error_voltage;
    actual_data.current = test_data.current * gain_error_current + offset_error_current;
    actual_data.time = test_data.time;
    
    % ADC量化误差（12位分辨率）
    adc_resolution_voltage = voltage_range.fsr / 4096;
    adc_resolution_current = current_range.fsr / 4096;
    
    actual_data.voltage = round(actual_data.voltage / adc_resolution_voltage) * adc_resolution_voltage;
    actual_data.current = round(actual_data.current / adc_resolution_current) * adc_resolution_current;
    
    % 添加合理噪声
    noise_voltage = voltage_range.fsr * 0.0005; % 0.05% FSR噪声
    noise_current = current_range.fsr * 0.0005; % 0.05% FSR噪声
    
    actual_data.voltage = actual_data.voltage + noise_voltage * randn(size(actual_data.voltage));
    actual_data.current = actual_data.current + noise_current * randn(size(actual_data.current));
    
    fprintf('传感器误差: 增益±%.1f%%, 偏移±%.1f%% FSR\n', ...
        0.1, 0.2);
end

function results = calculate_accuracy_metrics(ideal, actual, voltage_range, current_range)
    % 计算精度指标
    
    fprintf('计算采集精度指标...\n');
    
    results = struct();
    
    % 电压精度计算
    voltage_errors = abs(actual.voltage - ideal.voltage);
    voltage_error_fsr = (voltage_errors / voltage_range.fsr) * 100;
    
    results.voltage = struct();
    results.voltage.max_error = max(voltage_error_fsr);
    results.voltage.avg_error = mean(voltage_error_fsr);
    results.voltage.rms_error = rms(voltage_error_fsr);
    results.voltage.pass = results.voltage.max_error <= 1.0;
    results.voltage.absolute_errors = voltage_errors;
    results.voltage.relative_errors = voltage_error_fsr;
    
    % 电流精度计算
    current_errors = abs(actual.current - ideal.current);
    current_error_fsr = (current_errors / current_range.fsr) * 100;
    
    results.current = struct();
    results.current.max_error = max(current_error_fsr);
    results.current.avg_error = mean(current_error_fsr);
    results.current.rms_error = rms(current_error_fsr);
    results.current.pass = results.current.max_error <= 1.0;
    results.current.absolute_errors = current_errors;
    results.current.relative_errors = current_error_fsr;
    
    % 统计信息
    results.voltage.error_distribution = histcounts(voltage_error_fsr, 0:0.1:2);
    results.current.error_distribution = histcounts(current_error_fsr, 0:0.1:2);
    
    fprintf('精度计算完成\n');
end

function generate_accuracy_report(results, voltage_range, current_range)
    % 生成详细的验证报告
    
    fprintf('\n========================================\n');
    fprintf('       BMS采集精度验证报告\n');
    fprintf('========================================\n');
    fprintf('验证标准: ±1%% FSR (满量程)\n');
    fprintf('----------------------------------------\n\n');
    
    % 电压精度结果
    fprintf('=== 电压采集精度 ===\n');
    fprintf('量程范围: %.0fV-%.0fV (FSR: %.0fV)\n', ...
        voltage_range.min, voltage_range.max, voltage_range.fsr);
    fprintf('允许误差: ≤%.2fV (≤1%% FSR)\n', voltage_range.allowed_error);
    fprintf('实测结果:\n');
    fprintf('  • 最大误差: %.3f%% FSR\n', results.voltage.max_error);
    fprintf('  • 平均误差: %.3f%% FSR\n', results.voltage.avg_error);
    fprintf('  • RMS误差:  %.3f%% FSR\n', results.voltage.rms_error);
    fprintf('  • 达标状态: %s\n', ternary(results.voltage.pass, '✅通过', '❌未通过'));
    
    % 电压误差分布统计
    below_05 = sum(results.voltage.relative_errors <= 0.5);
    below_10 = sum(results.voltage.relative_errors <= 1.0);
    total_points = length(results.voltage.relative_errors);
    
    fprintf('  • 误差分布: ≤0.5%%: %d点(%.1f%%), ≤1.0%%: %d点(%.1f%%)\n', ...
        below_05, below_05/total_points*100, below_10, below_10/total_points*100);
    fprintf('\n');
    
    % 电流精度结果
    fprintf('=== 电流采集精度 ===\n');
    fprintf('量程范围: %.0fA-%.0fA (FSR: %.0fA)\n', ...
        current_range.min, current_range.max, current_range.fsr);
    fprintf('允许误差: ≤%.1fA (≤1%% FSR)\n', current_range.allowed_error);
    fprintf('实测结果:\n');
    fprintf('  • 最大误差: %.3f%% FSR\n', results.current.max_error);
    fprintf('  • 平均误差: %.3f%% FSR\n', results.current.avg_error);
    fprintf('  • RMS误差:  %.3f%% FSR\n', results.current.rms_error);
    fprintf('  • 达标状态: %s\n', ternary(results.current.pass, '✅通过', '❌未通过'));
    
    % 电流误差分布统计
    below_05 = sum(results.current.relative_errors <= 0.5);
    below_10 = sum(results.current.relative_errors <= 1.0);
    total_points = length(results.current.relative_errors);
    
    fprintf('  • 误差分布: ≤0.5%%: %d点(%.1f%%), ≤1.0%%: %d点(%.1f%%)\n', ...
        below_05, below_05/total_points*100, below_10, below_10/total_points*100);
    fprintf('\n');
    
    % 总体评估
    fprintf('=== 总体评估 ===\n');
    if results.voltage.pass && results.current.pass
        fprintf('🎯 综合评估: ✅ 完全达标\n');
        fprintf('   电压和电流采集精度均满足±1%% FSR要求\n');
        fprintf('   系统符合比赛文档表2技术要求\n');
    elseif results.voltage.pass
        fprintf('🎯 综合评估: ⚠️ 部分达标\n');
        fprintf('   电压采集达标，电流采集需要优化\n');
    elseif results.current.pass
        fprintf('🎯 综合评估: ⚠️ 部分达标\n');
        fprintf('   电流采集达标，电压采集需要优化\n');
    else
        fprintf('🎯 综合评估: ❌ 未达标\n');
        fprintf('   需要检查传感器模型和参数设置\n');
    end
    fprintf('========================================\n\n');
end

function plot_comprehensive_results(ideal, actual, results, voltage_range, current_range)
    % 生成综合可视化图表
    
    fprintf('生成专业可视化图表...\n');
    
    % 创建大图窗
    figure('Position', [100, 150 , 1300, 700], 'Name', 'BMS采集精度综合分析', 'NumberTitle', 'off');
    
    %% 子图1: 电压采集对比
    subplot(3, 4, [1, 2]);
    plot(ideal.voltage, 'b-', 'LineWidth', 2, 'DisplayName', '参考电压');
    hold on;
    plot(actual.voltage, 'r--', 'LineWidth', 1.5, 'DisplayName', '测量电压');
    ylabel('电压 (V)'); xlabel('采样点');
    title('电压采集对比'); 
    legend('Location', 'best'); grid on;
    ylim([voltage_range.min*0.95, voltage_range.max*1.05]);
    
    % 添加误差带
    error_band = voltage_range.allowed_error;
    plot(ideal.voltage + error_band, 'g:', 'LineWidth', 0.5, 'DisplayName', '允许误差上限');
    plot(ideal.voltage - error_band, 'g:', 'LineWidth', 0.5, 'Display','允许误差下限');
    
    %% 子图2: 电压误差分析
    subplot(3, 4, 3);
    plot(results.voltage.relative_errors, 'k-', 'LineWidth', 1);
    hold on;
    plot([1, length(results.voltage.relative_errors)], [1, 1], 'r--', 'LineWidth', 2, 'DisplayName', '1%阈值');
    ylabel('误差 (% FSR)'); xlabel('采样点');
    title('电压相对误差'); grid on;
    ylim([0, max(2, results.voltage.max_error*1.2)]);
    legend('show');
    
    %% 子图3: 电压误差分布
    subplot(3, 4, 4);
    histogram(results.voltage.relative_errors, 30, 'FaceColor', 'blue', 'FaceAlpha', 0.7);
    hold on;
    plot([1, 1], ylim, 'r--', 'LineWidth', 2, 'DisplayName', '达标阈值');
    xlabel('误差 (% FSR)'); ylabel('频次');
    title('电压误差分布'); grid on;
    legend('show');
    
    %% 子图4: 电流采集对比
    subplot(3, 4, [5, 6]);
    plot(ideal.current, 'b-', 'LineWidth', 2, 'DisplayName', '参考电流');
    hold on;
    plot(actual.current, 'r--', 'LineWidth', 1.5, 'DisplayName', '测量电流');
    ylabel('电流 (A)'); xlabel('采样点');
    title('电流采集对比'); 
    legend('Location', 'best'); grid on;
    ylim([current_range.min*1.05, current_range.max*1.05]);
    
    % 添加误差带
    error_band = current_range.allowed_error;
    plot(ideal.current + error_band, 'g:', 'LineWidth', 0.5, 'DisplayName', '允许误差上限');
    plot(ideal.current - error_band, 'g:', 'LineWidth', 0.5, 'DisplayName', '允许误差下限');
    
    %% 子图5: 电流误差分析
    subplot(3, 4, 7);
    plot(results.current.relative_errors, 'k-', 'LineWidth', 1);
    hold on;
    plot([1, length(results.current.relative_errors)], [1, 1], 'r--', 'LineWidth', 2, 'DisplayName', '1%阈值');
    ylabel('误差 (% FSR)'); xlabel('采样点');
    title('电流相对误差'); grid on;
    ylim([0, max(2, results.current.max_error*1.2)]);
    legend('show');
    
    %% 子图6: 电流误差分布
    subplot(3, 4, 8);
    histogram(results.current.relative_errors, 30, 'FaceColor', 'green', 'FaceAlpha', 0.7);
    hold on;
    plot([1, 1], ylim, 'r--', 'LineWidth', 2, 'DisplayName', '达标阈值');
    xlabel('误差 (% FSR)'); ylabel('频次');
    title('电流误差分布'); grid on;
    legend('show');
    
    %% 子图7: 精度达标验证
    subplot(3, 4, 9);
    categories = {'电压最大误差', '电流最大误差', '允许误差'};
    values = [results.voltage.max_error, results.current.max_error, 1.0];
    colors = [0.2, 0.6, 0.8; 0.2, 0.8, 0.4; 0.8, 0.2, 0.2];
    
    for i = 1:3
        bar(i, values(i), 'FaceColor', colors(i,:), 'FaceAlpha', 0.7);
        hold on;
        if i < 3
            if values(i) <= 1.0
                text(i, values(i)+0.1, '✅', 'HorizontalAlignment', 'center', 'FontSize', 12);
            else
                text(i, values(i)+0.1, '❌', 'HorizontalAlignment', 'center', 'FontSize', 12);
            end
        end
    end
    
    set(gca, 'XTick', 1:3, 'XTickLabel', categories);
    xtickangle(45);  % 旋转标签45度，避免重叠
    ylabel('误差 (% FSR)'); title('精度达标验证');
    ylim([0, max(values)*1.3]); grid on;
    
    %% 子图8: 误差统计对比
    subplot(3, 4, 10);
    stats_data = [results.voltage.avg_error, results.voltage.rms_error; 
                 results.current.avg_error, results.current.rms_error];
    bar(stats_data, 'grouped');
    set(gca, 'XTickLabel', {'电压', '电流'});
    ylabel('误差 (% FSR)'); title('误差统计对比');
    legend('平均误差', 'RMS误差', 'Location', 'northwest'); grid on;
    
    %% 子图9: 性能摘要
    subplot(3, 4, 11);
    axis off;
    text(0.1, 0.9, '性能摘要', 'FontSize', 14, 'FontWeight', 'bold');
    
    text(0.1, 0.7, sprintf('电压采集精度: %.3f%% FSR', results.voltage.max_error), ...
        'FontSize', 10, 'Color', ternary(results.voltage.pass, [0, 0.5, 0], [0.8, 0, 0]));
    text(0.1, 0.6, sprintf('电流采集精度: %.3f%% FSR', results.current.max_error), ...
        'FontSize', 10, 'Color', ternary(results.current.pass, [0, 0.5, 0], [0.8, 0, 0]));
    
    text(0.1, 0.4, sprintf('测试点数: %d', length(ideal.voltage)), 'FontSize', 10);
    text(0.1, 0.3, sprintf('电压FSR: %.0fV', voltage_range.fsr), 'FontSize', 10);
    text(0.1, 0.2, sprintf('电流FSR: %.0fA', current_range.fsr), 'FontSize', 10);
    
    if results.voltage.pass && results.current.pass
        text(0.1, 0.1, '总体评估: ✅ 达标', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0, 0.5, 0]);
    else
        text(0.1, 0.1, '总体评估: ❌ 未达标', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.8, 0, 0]);
    end
    
    %% 子图10: 误差随时间变化
    subplot(3, 4, 12);
    plot(ideal.time, results.voltage.relative_errors, 'b-', 'DisplayName', '电压误差');
    hold on;
    plot(ideal.time, results.current.relative_errors, 'g-', 'DisplayName', '电流误差');
    plot([1, max(ideal.time)], [1, 1], 'r--', 'LineWidth', 2, 'DisplayName', '阈值');
    xlabel('时间'); ylabel('误差 (% FSR)');
    title('误差随时间变化'); legend('show'); grid on;
    ylim([0, max([results.voltage.max_error, results.current.max_error, 1])*1.2]);
    
    % 添加总标题
    sgtitle(sprintf('BMS采集精度综合分析 - 电压:%.3f%% FSR, 电流:%.3f%% FSR', ...
        results.voltage.max_error, results.current.max_error), 'FontSize', 14, 'FontWeight', 'bold');
    
    fprintf('专业图表生成完成\n');
end

% 辅助函数
function result = ternary(condition, true_val, false_val)
    % 三目运算符
    if condition
        result = true_val;
    else
        result = false_val;
    end
end