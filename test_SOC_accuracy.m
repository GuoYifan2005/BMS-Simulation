function test_SOC_accuracy()
    % SOC精度验证脚本
    
 
    % 创建测试电池和SOC估算器
    cell_params.capacity = 14;
    sys_config.total_cells = 1; % 简化测试
    battery = BatteryModel(cell_params, sys_config);
    soc_estimator = SOCEstimator(0.5);
    
    % 测试参数
    test_time = 600; % 10分钟测试
    time_step = 1;
    current = -14; % 1C放电
    
    % 测试循环
    soc_errors = [];
    for t = 1:test_time
        battery.update(current, time_step, 25);
        [voltages, temps, socs] = battery.getMeasurements();
        
        estimated_soc = soc_estimator.update(current, voltages(1), temps(1), time_step, socs(1));
        true_soc = socs(1);
        
        soc_errors(end+1) = abs(estimated_soc - true_soc) * 100;
    end
    
    % 分析结果
    max_error = max(soc_errors);
    avg_error = mean(soc_errors);
    
    fprintf('SOC精度验证结果:\n');
    fprintf('最大误差: %.2f%%\n', max_error);
    fprintf('平均误差: %.2f%%\n', avg_error);
    if max_error <= 5
        status_str = '✔通过';
    else
        status_str = '✘未通过';
    end
    fprintf('达标状态: %s (要求≤5%%) \n', status_str);
    
    % 绘制误差曲线
    figure('Position', [200, 200, 600, 400]);
    plot(soc_errors, 'b-', 'LineWidth', 2);
    hold on;
    plot([1, test_time], [5, 5], 'r--', 'LineWidth', 2, 'DisplayName', '5%阈值');
    xlabel('时间 (s)'); ylabel('SOC误差 (%)');
    title(['SOC估算精度验证 - 最大误差: ', sprintf('%.2f%%', max_error)]);
    legend; grid on;
    
    fprintf('=== SOC精度验证完成 ===\n\n');
end