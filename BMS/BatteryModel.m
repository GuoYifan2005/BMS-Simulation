classdef BatteryModel < handle
    % 电池模型类 
    
    properties
        capacity double
        nominal_voltage double
        charge_cutoff double
        discharge_cutoff double
        weight double
        internal_resistance double
        dimensions_mm double
        energy_density_whkg double
        specific_heat double
        k_in_plane double
        k_through double
        soc double
        voltage double
        temperature double
        current double
        time double
    end
    
    methods
        function obj = BatteryModel(cell_params, ~)
            if nargin < 1
                cell_params = struct();
            end
            if nargin < 2
                config = struct('total_cells', 1);
            end
            obj.capacity = obj.getParam(cell_params, 'capacity', 14);
            obj.nominal_voltage = obj.getParam(cell_params, 'nominal_voltage', 3.5);
            obj.charge_cutoff = obj.getParam(cell_params, 'charge_cutoff', 4.2);
            obj.discharge_cutoff = obj.getParam(cell_params, 'discharge_cutoff', 2.5);
            obj.weight = obj.getParam(cell_params, 'weight', 121);
            obj.dimensions_mm = obj.getParam(cell_params, 'dimensions_mm', [10, 60, 100]);
            obj.energy_density_whkg = obj.getParam(cell_params, 'energy_density_whkg', 400);
            obj.specific_heat = obj.getParam(cell_params, 'specific_heat', 1160);
            obj.k_in_plane = obj.getParam(cell_params, 'k_in_plane', 18);
            obj.k_through = obj.getParam(cell_params, 'k_through', 1.3);
            obj.internal_resistance = obj.getParam(cell_params, 'internal_resistance', 0.0018);
            initial_soc = obj.getParam(cell_params, 'initial_soc', 0.5);
            initial_temp = obj.getParam(cell_params, 'initial_temp', 25);
            
            obj.soc = max(0, min(1, initial_soc));
            obj.temperature = initial_temp;
            obj.voltage = obj.calculateOCV(obj.soc, obj.temperature);
            obj.current = 0;
            obj.time = 0;
            
            fprintf('电池模型创建成功: SOC=%.1f%%, 电压=%.3fV\n', ...
                obj.soc*100, obj.voltage);
        end
        
        function value = getParam(~, params, field_name, default_value)
            if isfield(params, field_name)
                value = params.(field_name);
                if ~isnumeric(value)
                    warning('%s应为数值类型，使用默认值', field_name);
                    value = default_value;
                else
                    value = double(value);
                end
            else
                value = default_value;
            end
        end
        
        function update(obj, current, delta_time, ambient_temp)
            current = double(current);
            delta_time = double(delta_time);
            ambient_temp = double(ambient_temp);
            
            obj.current = current;
            obj.time = obj.time + delta_time;
            
            delta_soc = -current * delta_time / 3600 / obj.capacity;
            obj.soc = obj.soc + delta_soc;
            obj.soc = max(0, min(1, obj.soc));
            
            mass_kg = obj.weight / 1000;
            cp = obj.specific_heat;
            heat_generation = current^2 * obj.internal_resistance;
            temp_rise_adiabatic = heat_generation * delta_time / (mass_kg * cp + eps);
            
            thickness_m = obj.dimensions_mm(1) / 1000;
            width_m = obj.dimensions_mm(2) / 1000;
            length_m = obj.dimensions_mm(3) / 1000;
            area_face = width_m * length_m;
            r_th = thickness_m / max(obj.k_through * area_face, eps);
            cooling_term = (ambient_temp - obj.temperature) * (delta_time / (mass_kg * cp * r_th + eps));
            
            obj.temperature = obj.temperature + temp_rise_adiabatic + cooling_term;
            
            ocv = obj.calculateOCV(obj.soc, obj.temperature);
            obj.voltage = ocv - current * obj.internal_resistance;
        end
        
        function ocv = calculateOCV(~, soc, temperature)
            % 计算开路电压
            soc = max(0, min(1, double(soc)));
            temperature = double(temperature);
            
            try
                % 使用提供的 OCV-SOC 数据表（0~100%）
                soc_points = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
                ocv_points = [2.5000, 2.8922, 3.0643, 3.2100, 3.3345, 3.4605, 3.60165, 3.69465, 3.8218, 3.88735, 4.1385];
                
                % 平滑插值（pchip 避免尖点）
                ocv = interp1(soc_points, ocv_points, soc, 'pchip', 'extrap');
                
                % 温度补偿（线性近似）
                temp_compensation = (temperature - 25) * 0.0003;
                ocv = ocv + temp_compensation;
                
            catch
                ocv = 3.5; % 默认值
            end
        end
        
        function [voltages, temperatures, socs] = getMeasurements(obj, num_cells)
            % 获取测量值
            if nargin < 2
                num_cells = 1;
            end
            
            voltages = zeros(1, num_cells);
            temperatures = zeros(1, num_cells);
            socs = zeros(1, num_cells);
            
            for i = 1:num_cells
                voltage_noise = (rand() - 0.5) * 0.02;
                temp_noise = (rand() - 0.5) * 0.2;
                
                voltages(i) = obj.voltage + voltage_noise;
                temperatures(i) = obj.temperature + temp_noise;
                socs(i) =  obj.soc;
            end
        end
    end
end