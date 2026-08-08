from odbAccess import *
import numpy as np
import matplotlib.pyplot as plt

# 打开ODB文件
odb_path = 'Job-7.odb'  # 替换为您的ODB文件路径
odb = openOdb(path=odb_path)

# 材料参数
resistivity = 1.68e-5  # 铜的电阻率(Ohm·mm)
hardness = 1e9         # 材料硬度(Pa)
oxide_resistivity = 2e-6  # 氧化膜电阻率
#  oxide_thickness = 2e-9    # 氧化膜厚度(m)
oxide_thickness = 0
# 获取步骤
step_name = 'Step-2-Open1'  # 替换为您的步骤名称
step = odb.steps[step_name]

# 准备数据收集
time_points = []
arc_resistance_values = []   # 弧触头电阻
main_resistance_values = []  # 主触头电阻
total_resistance_values = [] # 总电阻

# 定义接触对信息 - 根据您提供的信息修改
contacts = {
    'arc': {
        'nodeset': 'NodeSet  Z000001',  # 弧触头的节点集 - 请确认实际名称
        'carea_key': 'CAREA    ASSEMBLY_SECSURF_HU/ASSEMBLY_MAINSURF_HU',  # 弧触头的CAREA输出
        'cpress_prefix': 'CPRESS   ASSEMBLY_SECSURF_HU/ASSEMBLY_MAINSURF_HU',  # 弧触头的CPRESS输出
        'node_pattern': 'Node JHCT'  # 静弧触头节点标识
    },
    'main': {
        'nodeset': 'NodeSet  Z000002',  # 主触头的节点集 - 请确认实际名称
        'carea_key': 'CAREA    ASSEMBLY_SECSURF_ZHU/ASSEMBLY_MAINSURF_ZHU',  # 主触头的CAREA输出
        'cpress_prefix': 'CPRESS   ASSEMBLY_SECSURF_ZHU/ASSEMBLY_MAINSURF_ZHU',  # 主触头的CPRESS输出
        'node_pattern': 'Node CHUZHI'  # 静主触头节点标识
    }
}

# 获取时间点列表
time_points_set = False

# 处理每组接触
for contact_type, contact_info in contacts.items():
    print(f"Processing {contact_type} contacts...")
    nodeset_region_key = contact_info['nodeset']
    
    # 检查该节点集是否存在
    if nodeset_region_key not in step.historyRegions:
        print(f"Warning: {nodeset_region_key} not found in history regions for {contact_type} contacts")
        print("Available history regions:")
        for key in step.historyRegions.keys():
            if "NodeSet" in key:
                print(f" - {key}")
        # 继续处理下一组接触
        continue
    
    area_region = step.historyRegions[nodeset_region_key]
    carea_key = contact_info['carea_key']
    
    # 检查CAREA输出是否存在
    if carea_key not in area_region.historyOutputs:
        print(f"Warning: {carea_key} not found in {nodeset_region_key} for {contact_type} contacts")
        print("Available history outputs for this region:")
        for key in area_region.historyOutputs.keys():
            print(f" - {key}")
        # 继续处理下一组接触
        continue
    
    # 获取CAREA数据
    carea_data = area_region.historyOutputs[carea_key].data
    print(f"Found CAREA data with {len(carea_data)} points for {contact_type} contacts")
    
    # 设置时间点（如果尚未设置）
    if not time_points_set:
        time_points = [point[0] for point in carea_data]
        time_points_set = True
    
    # 收集所有相关节点的CPRESS数据
    node_regions = {}
    node_pattern = contact_info['node_pattern']
    cpress_prefix = contact_info['cpress_prefix']
    
    for region_key in step.historyRegions.keys():
        if node_pattern in region_key:
            region = step.historyRegions[region_key]
            if cpress_prefix in region.historyOutputs:
                node_regions[region_key] = region.historyOutputs[cpress_prefix].data
    
    print(f"Found CPRESS data for {len(node_regions)} nodes for {contact_type} contacts")
    
    # 计算每个时间点的电阻
    resistance_values = []
    for i, (time, area) in enumerate(carea_data):
        # 如果没有接触(面积为0)，则电阻为无穷大
        if area <= 0:
            resistance_values.append(float('inf'))
            continue
            
        # 计算该时间点的总接触力和活动接触点
        total_force = 0
        active_contacts = 0
        for node_data in node_regions.values():
            # 确保我们有与当前时间点匹配的数据
            if i < len(node_data):
                node_time, pressure = node_data[i]
                if pressure > 0:
                    # 假设每个节点代表一个单元面积
                    node_area = area / len(node_regions)  # 简化估计
                    force = pressure * node_area
                    total_force += force
                    active_contacts += 1
        
        # 使用Holm接触理论计算电阻
        if active_contacts > 0:
            # 平均每个接触点的力
            avg_force_per_contact = total_force / active_contacts
            
            # 每个接触点的半径: a = sqrt(F/πH)
            contact_radius = np.sqrt(avg_force_per_contact / (np.pi * hardness))
            
            # 单个接触点的电阻: R = ρ/2a
            point_resistance = resistivity / (2 * contact_radius)
            
            # 考虑氧化膜的额外电阻: R_f = ρ_f·t/A
            oxide_resistance = oxide_resistivity * oxide_thickness / area
            
            # 并联计算总电阻: 1/R_total = n/R_point
            # 其中n是接触点数量
            contact_resistance = point_resistance / active_contacts
            total_resistance = contact_resistance + oxide_resistance
        else:
            total_resistance = float('inf')
        
        resistance_values.append(total_resistance)
    
    # 存储该类型触头的电阻值
    if contact_type == 'arc':
        arc_resistance_values = resistance_values
    elif contact_type == 'main':
        main_resistance_values = resistance_values

# 确保两种触头的电阻值数组长度相同
if not arc_resistance_values:
    arc_resistance_values = [float('inf')] * len(time_points)
    print("警告: 未能计算弧触头电阻，使用无穷大值替代")
if not main_resistance_values:
    main_resistance_values = [float('inf')] * len(time_points)
    print("警告: 未能计算主触头电阻，使用无穷大值替代")

# 计算总电阻 (并联)
for i in range(len(time_points)):
    arc_r = arc_resistance_values[i]
    main_r = main_resistance_values[i]
    
    # 计算并联电阻
    if arc_r == float('inf') and main_r == float('inf'):
        total_r = float('inf')  # 两者都是无穷大，总电阻也是无穷大
    elif arc_r == float('inf'):
        total_r = main_r  # 弧触头断开，只有主触头
    elif main_r == float('inf'):
        total_r = arc_r   # 主触头断开，只有弧触头
    else:
        total_r = 1.0 / ((1.0 / arc_r) + (1.0 / main_r))  # 并联公式
    
    total_resistance_values.append(total_r)

# 确保我们有数据要绘制
if not time_points:
    print("No data to plot. Check your ODB file and output requests.")
    odb.close()
    exit()

# 处理无穷大值以便于绘图显示
def process_for_plotting(resistance_list):
    # 找出非无穷大的最大值
    finite_values = [r for r in resistance_list if r != float('inf')]
    if finite_values:
        max_finite = max(finite_values)
        # 将无穷大替换为最大有限值的10倍
        return [r if r != float('inf') else max_finite * 10 for r in resistance_list]
    else:
        # 如果所有值都是无穷大，返回一个常数数组
        return [1.0e6] * len(resistance_list)

arc_plot_values = process_for_plotting(arc_resistance_values)
main_plot_values = process_for_plotting(main_resistance_values)
total_plot_values = process_for_plotting(total_resistance_values)


# Create three separate figures as requested
# Figure 1: Arc Contact Resistance
plt.figure(figsize=(10, 6))
plt.plot(time_points, arc_plot_values, 'r-', linewidth=2)
plt.xlabel('Time (s)', fontsize=12)
plt.ylabel('Resistance (Ω)', fontsize=12)
plt.title('Arc Contact Dynamic Resistance', fontsize=14)
plt.grid(True)
plt.savefig('Arc_Contact_Resistance.png', dpi=300)
plt.close()

# Figure 2: Main Contact Resistance
plt.figure(figsize=(10, 6))
plt.plot(time_points, main_plot_values, 'g-', linewidth=2)
plt.xlabel('Time (s)', fontsize=12)
plt.ylabel('Resistance (Ω)', fontsize=12)
plt.title('Main Contact Dynamic Resistance', fontsize=14)
plt.grid(True)
plt.savefig('Main_Contact_Resistance.png', dpi=300)
plt.close()

# Figure 3: Total Resistance
plt.figure(figsize=(10, 6))
plt.plot(time_points, total_plot_values, 'b-', linewidth=2)
plt.xlabel('Time (s)', fontsize=12)
plt.ylabel('Resistance (Ω)', fontsize=12)
plt.title('Total Dynamic Resistance', fontsize=14)
plt.grid(True)
plt.savefig('Total_Dynamic_Resistance.png', dpi=300)
plt.close()

# Save results to CSV file
import csv
with open('2--Contact_Resistance_Data.csv', 'w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(['Time(s)', 'Arc_Contact_Resistance(Ω)', 'Main_Contact_Resistance(Ω)', 'Total_Resistance(Ω)'])
    for i in range(len(time_points)):
        arc_r = "inf" if arc_resistance_values[i] == float('inf') else arc_resistance_values[i]
        main_r = "inf" if main_resistance_values[i] == float('inf') else main_resistance_values[i]
        total_r = "inf" if total_resistance_values[i] == float('inf') else total_resistance_values[i]
        writer.writerow([time_points[i], arc_r, main_r, total_r])

# Close ODB
odb.close()

print("Analysis complete! Results saved as 'Arc_Contact_Resistance.png', 'Main_Contact_Resistance.png', 'Total_Dynamic_Resistance.png', and 'Contact_Resistance_Data.csv'")