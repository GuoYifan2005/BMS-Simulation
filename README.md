# BMS电池管理系统仿真

## 项目简介

基于MATLAB的电池管理系统（BMS）仿真平台，实现20S3P（60节电芯）锂电池包的监控、均衡和热管理功能。

## 核心功能

- **电池建模**: 精确的电芯物理模型，包含SOC-OCV特性、温度动态响应
- **SOC估算**: 基于扩展卡尔曼滤波（EKF）算法，估算精度≤5%
- **均衡控制**: 主动均衡算法，支持并行均衡，电压不均衡度≤100mV
- **热失控预警**: 三级预警机制（温度异常/高温告警/热失控风险）
- **采集精度**: 电压/电流采集精度±1% FSR

## 快速使用

% 运行完整BMS仿真
results = simulateBMS();

% 运行功能测试
test_balancing();              % 均衡功能测试
test_SOC_accuracy();           % SOC精度测试
test_acquisition_accuracy();   % 采集精度测试
test_thermal_warning();        % 热失控预警测试## 文件说明

### 核心模块
- `BatteryModel.m` - 电池模型类
- `SOCEstimator.m` - SOC估算器（EKF算法）
- `BalancingController.m` - 均衡控制器
- `ThermalRunawayWarning.m` - 热失控预警系统
- `simulateBMS.m` - 主仿真函数

### 测试脚本
- `test_balancing.m` - 均衡功能验证
- `test_SOC_accuracy.m` - SOC精度验证
- `test_acquisition_accuracy.m` - 采集精度验证
- `test_thermal_warning.m` - 热失控预警验证

## 技术规格

| 参数 | 数值 |
|------|------|
| 电池包配置 | 20S3P (60节电芯) |
| 标称电压 | 70V |
| 电池包容量 | 42Ah |
| SOC估算误差 | ≤5% |
| 电压采集精度 | ±1% FSR |
| 电流采集精度 | ±1% FSR |
| 电压不均衡度 | ≤100mV |
| 最大工作温度 | ≤60℃ |

## 系统特点

1. **面向对象设计**: 采用MATLAB类实现模块化架构
2. **高精度仿真**: 考虑采样误差、量化误差等实际因素
3. **完整测试**: 提供4个测试脚本验证各项功能
4. **可视化分析**: 自动生成性能分析图表

## 运行环境

- MATLAB R2020b+
- Statistics and Machine Learning Toolbox
