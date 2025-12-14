bms-simulation/
├── Core Modules/                 % 核心功能模块
│   ├── BatteryModel.m           % 电池物理模型
│   ├── SOCEstimator.m           % SOC 估计算法（EKF）
│   ├── BalancingController.m    % 均衡控制器
│   └── ThermalRunawayWarning.m  % 热失控预警
├── Simulation/                  % 系统仿真
│   └── simulateBMS.m           % 主仿真程序
├── Tests/                       % 测试验证
│   ├── test_acquisition_accuracy.m    % 采集精度测试
│   ├── test_SOC_accuracy.m           % SOC 精度测试
│   ├── test_balancing.m              % 均衡功能测试
│   └── test_thermal_warning.m        % 热预警测试
├── Docs/                        % 文档资料
│   └── BMS系统设计方案技术文档.pdf
└── README.md
