import pandas as pd

def clean_excel_to_csv(input_file, output_file):
    print(f"正在读取 Excel 文件: {input_file} ...")
    
    # 读取 Excel 文件
    # header=2 表示表头在 Excel 的第3行（索引从0开始，所以是2）
    # 如果您的 Excel 文件有多个 Sheet，默认会读取第一个。
    # 如果需要指定 Sheet，可以加参数 sheet_name='Sheet1'
    try:
        df = pd.read_excel(input_file, header=2)
    except FileNotFoundError:
        print("错误：未找到文件，请检查文件名和路径是否正确。")
        return
    except Exception as e:
        print(f"读取文件时发生错误: {e}")
        return

    # 1. 去除单独成行的学院名称和空行
    # 逻辑：保留“课程序号”列不为空的行
    df_cleaned = df.dropna(subset=['课程序号'])

    # 2. 去除重复的表头
    # 逻辑：去除“课程序号”列内容等于“课程序号”的行
    df_cleaned = df_cleaned[df_cleaned['课程序号'] != '课程序号']

    # 3. 保存为标准的 CSV 格式
    # index=False: 不保存行索引
    # encoding='utf-8-sig': 确保中文在 Excel 打开时不乱码
    df_cleaned.to_csv(output_file, index=False, encoding='utf-8-sig')
    
    print(f"处理完成！\n原始行数（含表头空行）: {len(df)}")
    print(f"清理后行数: {len(df_cleaned)}")
    print(f"文件已保存至: {output_file}")

# --- 配置部分 ---
input_filename = 'all.xlsx'       # 您的 Excel 文件名
output_filename = 'cleaned_all.csv' # 输出的 CSV 文件名

# --- 执行 ---
if __name__ == '__main__':
    # 确保您已经安装了 openpyxl 库 (pip install openpyxl)
    clean_excel_to_csv(input_filename, output_filename)