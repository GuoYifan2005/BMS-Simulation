function test_thermal_warning()
    % 热失控预警测试 
    
    try  
       
        %% 1. 测试配置
        warning_thresholds = [60, 70, 80]; % 一级60℃, 二级70℃, 三级80℃
        
        fprintf('预警阈值配置:\n');
        fprintf('  一级预警(温度异常): ≥%d℃\n', warning_thresholds(1));
        fprintf('  二级预警(高温告警): ≥%d℃\n', warning_thresholds(2));
        fprintf('  三级预警(热失控风险): ≥%d℃\n\n', warning_thresholds(3));
        
        %% 2. 生成测试温度序列
        temperatures = 25:2:85; % 从25℃到85℃，2℃步进
        warning_levels = zeros(size(temperatures));
        
        fprintf('开始温度扫描测试...\n');
        fprintf('温度(℃) | 预警级别 | 状态\n');
        fprintf('--------|----------|-----------------\n');
        
        %% 3. 执行多级预警测试
        for i = 1:length(temperatures)
            temp = temperatures(i);
            
            % 多级预警判断逻辑
            if temp >= warning_thresholds(3)
                warning_levels(i) = 3;
                status = '三级: 热失控风险';
            elseif temp >= warning_thresholds(2)
                warning_levels(i) = 2;
                status = '二级: 高温告警';
            elseif temp >= warning_thresholds(1)
                warning_levels(i) = 1;
                status = '一级: 温度异常';
            else
                warning_levels(i) = 0;
                status = '正常';
            end
            
            % 只显示预警状态变化
            if i == 1 || warning_levels(i) ~= warning_levels(i-1)
                fprintf('%6.1f  | %8d | %s\n', temp, warning_levels(i), status);
            end
        end
        
        %% 4. 生成测试报告
        fprintf('\n=== 测试结果汇总 ===\n');
        total_points = length(temperatures);
        level0_count = sum(warning_levels == 0);
        level1_count = sum(warning_levels == 1);
        level2_count = sum(warning_levels == 2);
        level3_count = sum(warning_levels == 3);
        
        fprintf('测试点数: %d\n', total_points);
        fprintf('正常状态: %d点 (%.1f%%)\n', level0_count, level0_count/total_points*100);
        fprintf('一级预警: %d点 (%.1f%%)\n', level1_count, level1_count/total_points*100);
        fprintf('二级预警: %d点 (%.1f%%)\n', level2_count, level2_count/total_points*100);
        fprintf('三级预警: %d点 (%.1f%%)\n', level3_count, level3_count/total_points*100);
 %% 5. 验证多级预警功能
        if level1_count > 0 && level2_count > 0 && level3_count > 0
            fprintf('✅ 多级预警功能: 完全正常\n');
            fprintf('   成功检测到所有预警级别升级过程\n');
        else
            fprintf('⚠️ 多级预警功能: 部分正常\n');
            if level1_count == 0
                fprintf('   缺失一级预警触发\n');
            end
            if level2_count == 0
                fprintf('   缺失二级预警触发\n');
            end
            if level3_count == 0
                fprintf('   缺失三级预警触发\n');
            end
        end
        
        %% 6. 绘制专业图表
        fprintf('\n=== 生成可视化图表 ===\n');
        plot_thermal_warning_results(temperatures, warning_levels, warning_thresholds);
        fprintf('图表生成完成\n');
        
        fprintf('\n========================================\n');
        fprintf('   热失控预警测试完成\n');
        fprintf('========================================\n');       
    catch ME  
        fprintf('\n❌ 测试执行错误: %s\n', ME.message);
        fprintf('错误位置: %s, 行: %d\n', ME.stack(1).file, ME.stack(1).line);
        fprintf('\n建议检查:\n');
        fprintf('1. 确保try-catch结构完整\n');
        fprintf('2. 检查变量名和函数调用\n');
        fprintf('3. 验证温度数据范围\n');
    end
end

function plot_thermal_warning_results(temperatures, warning_levels, thresholds)
    % 绘制热失控预警专业图表 
   
    % 创建图形窗口
    figure('Position', [100, 150, 1200, 700], 'Name', '热失控预警系统分析', 'NumberTitle', 'off');
    
    % 子图1: 温度变化与预警级别
    subplot(2, 3, [1, 2]);
    hold on;
    
    % 绘制温度曲线
    time_points = 1:length(temperatures);
    plot(time_points, temperatures, 'b-', 'LineWidth', 3, 'DisplayName', '电池温度');
    
    % 添加预警区域背景色
    y_limits = [min(temperatures)-5, max(temperatures)+5];
    
    % 三级预警区域 (红色)
    patch([min(time_points), max(time_points), max(time_points), min(time_points)], ...
          [thresholds(3), thresholds(3), y_limits(2), y_limits(2)], ...
          [1, 0.8, 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'DisplayName', '三级预警区');
    
    % 二级预警区域 (黄色)
    patch([min(time_points), max(time_points), max(time_points), min(time_points)], ...
          [thresholds(2), thresholds(2), thresholds(3), thresholds(3)], ...
          [1, 1, 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'DisplayName', '二级预警区');
    
    % 一级预警区域 (绿色)
    patch([min(time_points), max(time_points), max(time_points), min(time_points)], ...
          [thresholds(1), thresholds(1), thresholds(2), thresholds(2)], ...
          [0.8, 1, 0.8], 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'DisplayName', '一级预警区');
    
    % 添加预警阈值线
    plot([min(time_points), max(time_points)], [thresholds(1), thresholds(1)], ...
         'g--', 'LineWidth', 2, 'DisplayName', '一级阈值(60℃)');
    plot([min(time_points), max(time_points)], [thresholds(2), thresholds(2)], ...
         'y--', 'LineWidth', 2, 'DisplayName', '二级阈值(70℃)');
    plot([min(time_points), max(time_points)], [thresholds(3), thresholds(3)], ...
         'r--', 'LineWidth', 2, 'DisplayName', '三级阈值(80℃)');
    
    % 标记预警点
    warning_colors = [0.2, 0 0.2; 1, 0.8, 0; 1, 0.2, 0.2]; % 绿,黄,红
    for level = 1:3
        level_indices = find(warning_levels == level);
        if ~isempty(level_indices)
            scatter(time_points(level_indices), temperatures(level_indices), ...
                    50, warning_colors(level,:), 'filled', ...
                    'DisplayName', sprintf('%d级预警点', level));
        end
    end
    
    xlabel('测试点序号'); ylabel('温度 (℃)');
    title('温度监控与多级预警'); 
    legend('show', 'Location', 'northwest');
    grid on;
    ylim(y_limits);
    
    % 子图2: 预警级别时间线
    subplot(2, 3, 3);
    stem(time_points, warning_levels, 'filled', 'MarkerSize', 4, 'LineWidth', 1.5);
    xlabel('测试点序号'); ylabel('预警级别');
    ylim([-0.5, 3.5]); yticks(0:3);
    yticklabels({'正常', '一级', '二级', '三级'});
    title('预警级别时间线'); grid on;
    
    % 添加预警级别说明
    text(0.05, 0.9, '0:正常 | 1:温度异常 | 2:高温告警 | 3:热失控风险', ...
         'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white');
    
    % 子图3: 预警级别统计
    subplot(2, 3, 4);
    warning_counts = zeros(1, 4);
    for i = 0:3
        warning_counts(i+1) = sum(warning_levels == i);
    end
    
    % 只显示有数据的部分
    non_zero_indices = warning_counts > 0;
    pie_data = warning_counts(non_zero_indices);
    pie_labels = {'正常', '一级预警', '二级预警', '三级预警'};
    pie_labels = pie_labels(non_zero_indices);
    
    colors = [0.8, 0.8, 0.8; 0.2, 0.8, 0.2; 1, 0.8, 0; 1, 0.2, 0.2];
    colors = colors(non_zero_indices, :);
    
    pie(pie_data, pie_labels);
    colormap(colors);
    title('预警事件统计分布');
    
    % 子图4: 温度分布直方图
    subplot(2, 3, 5);
    histogram(temperatures, 15, 'FaceColor', 'blue', 'FaceAlpha', 0.7);
    hold on;
    
    % 添加预警阈值线
    y_lim = ylim;
    plot([thresholds(1), thresholds(1)], [0, y_lim(2)], 'g--', 'LineWidth', 2, 'DisplayName', '一级阈值');
    plot([thresholds(2), thresholds(2)], [0, y_lim(2)], 'y--', 'LineWidth', 2, 'DisplayName', '二级阈值');
    plot([thresholds(3), thresholds(3)], [0, y_lim(2)], 'r--', 'LineWidth', 2, 'DisplayName', '三级阈值');
    
    xlabel('温度 (℃)'); ylabel('频次');
    title('温度分布直方图'); 
    legend('温度分布', '一级阈值', '二级阈值', '三级阈值', 'Location', 'northwest');
    grid on;
    
    % 子图5: 预警级别与温度关系 - 修复版
    subplot(2, 3, 6);
    
    % 为每个预警级别收集数据
    warning_data = cell(1, 4);
    for i = 0:3
        warning_data{i+1} = temperatures(warning_levels == i);
    end
    
    % 移除空的数据
    valid_indices = ~cellfun(@isempty, warning_data);
    box_data = warning_data(valid_indices);
    box_labels = {'正常', '一级', '二级', '三级'};
    box_labels = box_labels(valid_indices);
    
    
    if ~isempty(box_data) && length(box_data) > 0
        try
            % 方法1: 尝试使用cell2mat（如果维度一致）
            if length(unique(cellfun(@length, box_data))) == 1
                % 所有数组长度相同，可以安全使用cell2mat
                boxplot(cell2mat(box_data'), box_labels, 'Colors', 'brgk');
            else
                % 方法2: 使用分组数据（安全方法）
                all_data = [];
                group_labels = [];
                for j = 1:length(box_data)
                    if ~isempty(box_data{j})
                        all_data = [all_data, box_data{j}];
                        group_labels = [group_labels, repmat(j, 1, length(box_data{j}))];
                    end
                end
                if ~isempty(all_data)
                    boxplot(all_data, group_labels, 'Labels', box_labels, 'Colors', 'brgk');
                else
                    text(0.5, 0.5, '无有效数据', 'HorizontalAlignment', 'center');
                end
            end
        catch ME
            % 方法3: 备用方案 - 使用散点图
            fprintf('箱线图生成失败，使用散点图替代: %s\n', ME.message);
            hold on;
            for j = 1:length(box_data)
                if ~isempty(box_data{j})
                    scatter(repmat(j, size(box_data{j})), box_data{j}, 40, 'filled', 'MarkerFaceAlpha', 0.6);
                end
            end
            set(gca, 'XTick', 1:length(box_labels), 'XTickLabel', box_labels);
            ylabel('温度 (℃)');
            title('预警级别与温度关系（散点图）');
        end
    else
        text(0.5, 0.5, '无预警数据', 'HorizontalAlignment', 'center');
    end
    
    if ~exist('title_set', 'var')
        ylabel('温度 (℃)'); 
        xlabel('预警级别');
        title('预警级别与温度关系');
    end
    grid on;
    
  
    warning_counts = zeros(1, 4);
    for i = 0:3
        warning_counts(i+1) = sum(warning_levels == i);
    end
    
    text(0.05, 0.95, sprintf('性能摘要:\n• 测试点数: %d\n• 温度范围: %.1f-%.1f℃\n• 预警事件: %d次\n• 多级预警: %s', ...
        length(temperatures), min(temperatures), max(temperatures), ...
        sum(warning_levels > 0), ternary(all(warning_counts(2:4) > 0), '正常', '异常')), ...
        'Units', 'normalized', 'FontSize', 10, 'BackgroundColor', 'white', ...  % ✅ 修复：参数分开
        'VerticalAlignment', 'top');
    
    % 总标题
    sgtitle('热失控预警系统综合分析 - 多级预警机制验证', 'FontSize', 14, 'FontWeight', 'bold');
    
    fprintf('专业图表生成完成 - 5个子图展示完整预警分析\n');
end

function result = ternary(condition, true_val, false_val)
    % 三目运算符辅助函数
    if condition
        result = true_val;
    else
        result = false_val;
    end
end