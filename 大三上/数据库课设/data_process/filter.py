import pandas as pd

# 读取 CSV 文件
df = pd.read_csv('cleaned_all.csv')

# 更新需要保留的列名，加入 '排课信息'
columns_to_keep = ['新课程序号','课程名称','课程性质', '校区', '排课信息']

# 提取指定列
df_filtered = df[columns_to_keep]

# 重命名 '授课教师' 为 '授课老师'
df_filtered = df_filtered.rename(columns={'授课教师': '授课老师'})

# 将结果保存为新的 CSV 文件
df_filtered.to_csv('filtered_courses.csv', index=False)

# 打印前几行查看结果
print(df_filtered.head())