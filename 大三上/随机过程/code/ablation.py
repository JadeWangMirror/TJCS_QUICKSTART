import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.gaussian_process import GaussianProcessRegressor
from sklearn.gaussian_process.kernels import RBF, ConstantKernel as C, WhiteKernel
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error
import os
import glob
import warnings

warnings.filterwarnings('ignore')

def load_data(file_path):
    df = pd.read_csv(file_path)
    df['Date'] = pd.to_datetime(df['Date'])
    df = df.sort_values('Date').reset_index(drop=True)
    
    col = 'Close/Last' if 'Close/Last' in df.columns else 'Close'
    if df[col].dtype == object:
        df[col] = df[col].str.replace('$', '').str.replace(',', '').astype(float)
    return df[col].values

def get_features_and_target(raw_prices, use_diff, window_size):
    """
    根据配置生成特征X和标签y
    """
    if use_diff:
        data = np.diff(raw_prices) # 长度 len-1
    else:
        data = raw_prices # 长度 len
        
    X, y = [], []
    # 构造滑动窗口
    for i in range(window_size, len(data)):
        X.append(data[i-window_size:i])
        y.append(data[i])
        
    return np.array(X), np.array(y).reshape(-1, 1)

def run_four_models_comparison(file_path):
    base_name = os.path.splitext(os.path.basename(file_path))[0]
    print(f"正在处理文件: {file_path}")
    
    raw_prices = load_data(file_path)
    
    # 定义四个模型配置
    # 1. GPR (Baseline): Raw Data, Window=1
    # 2. GPR+DIFF: Diff Data, Window=1
    # 3. GPR+WINDOW: Raw Data, Window=5
    # 4. ALL (Full): Diff Data, Window=5
    configs = [
        {"name": "GPR (Raw, Win=1)",       "diff": False, "win": 1, "pos": (0, 0), "color": "purple"},
        {"name": "GPR+DIFF (Diff, Win=1)", "diff": True,  "win": 1, "pos": (0, 1), "color": "green"},
        {"name": "GPR+WINDOW (Raw, Win=5)", "diff": False, "win": 5, "pos": (1, 0), "color": "orange"},
        {"name": "ALL (Diff, Win=5)",      "diff": True,  "win": 5, "pos": (1, 1), "color": "red"},
    ]
    
    # 统一划分训练集测试集索引 (80%)
    # 为了保证所有图的"Actual"曲线完全一致，我们需要锁定测试集的时间段
    # 我们以 raw_prices 的索引为基准
    total_len = len(raw_prices)
    split_idx = int(total_len * 0.8)
    
    # 实际测试集价格 (用于绘图的 Ground Truth)
    # 我们统一展示从 split_idx 开始的数据
    actual_test_prices = raw_prices[split_idx:]
    test_len = len(actual_test_prices)
    time_indices = np.arange(test_len)
    
    fig, axes = plt.subplots(2, 2, figsize=(20, 12))
    
    for conf in configs:
        ax = axes[conf['pos']]
        print(f"--> 运行模型: {conf['name']}")
        
        # 1. 准备数据
        X, y = get_features_and_target(raw_prices, conf['diff'], conf['win'])
        
        # 2. 确定切分点
        # 目标：我们需要预测 raw_prices[split_idx] 及之后的值
        # 
        # Case A: Diff 模式
        # y[i] 对应 diff[i] = price[i+1] - price[i] (在原数组中)
        # diff 数组的索引 j 对应 raw_prices 索引 j+1 的变化量
        # 我们要预测 price[split_idx]，即需要知道 diff[split_idx-1]
        # 在构建的 y 中，y[k] = diff[k+window]
        # 我们需要 y 对应 diff[split_idx-1:] 
        # 即 diff索引 >= split_idx-1
        # 所以 k+window >= split_idx-1  => k >= split_idx - 1 - window
        # 
        # Case B: Raw 模式
        # y[i] 对应 price[i] (在原数组中)
        # 我们要预测 price[split_idx]，即需要 y 对应 price[split_idx:]
        # y[k] = price[k+window]
        # k+window >= split_idx => k >= split_idx - window
        
        if conf['diff']:
            test_start_k = split_idx - 1 - conf['win']
        else:
            test_start_k = split_idx - conf['win']
            
        # 修正边界
        test_start_k = max(0, test_start_k)
        
        # 划分训练/测试
        X_train = X[:test_start_k]
        y_train = y[:test_start_k]
        
        # 我们只需要预测与 actual_test_prices 长度对应的部分
        # 但为了严谨，我们取剩余所有作为 potential test，然后截断
        X_test = X[test_start_k:]
        
        # 3. 训练 (带采样加速)
        sample_step = max(1, len(X_train) // 200)
        scaler_X = StandardScaler().fit(X_train[::sample_step])
        scaler_y = StandardScaler().fit(y_train[::sample_step])
        
        X_train_s = scaler_X.transform(X_train[::sample_step])
        y_train_s = scaler_y.transform(y_train[::sample_step])
        X_test_s = scaler_X.transform(X_test)
        
        kernel = C(1.0) * RBF(1.0) + WhiteKernel(0.1)
        gp = GaussianProcessRegressor(kernel=kernel, n_restarts_optimizer=0, random_state=42)
        gp.fit(X_train_s, y_train_s.ravel())
        
        # 4. 预测
        y_pred_s, sigma_s = gp.predict(X_test_s, return_std=True)
        y_pred_raw = scaler_y.inverse_transform(y_pred_s.reshape(-1, 1))
        sigma_raw = sigma_s * scaler_y.scale_[0]
        
        # 5. 还原与对齐
        # 我们只需要前 test_len 个点
        n_points = min(len(y_pred_raw), test_len)
        y_pred_aligned = y_pred_raw[:n_points]
        sigma_aligned = sigma_raw[:n_points]
        
        # 还原为绝对价格
        if conf['diff']:
            # 预测的是变化量
            # 基准是前一天的价格。
            # 我们要预测 price[split_idx]，基准是 price[split_idx-1]
            base_prices = raw_prices[split_idx-1 : split_idx-1+n_points].reshape(-1, 1)
            pred_prices = base_prices + y_pred_aligned
        else:
            # 预测的是价格本身
            pred_prices = y_pred_aligned
            
        # 6. 计算指标
        # 截取对应的 Actual (以防长度不一致)
        curr_actual = actual_test_prices[:n_points].reshape(-1, 1)
        curr_indices = time_indices[:n_points]
        
        rmse = np.sqrt(mean_squared_error(curr_actual, pred_prices))
        
        # 趋势准确率
        # 需要昨天价格计算实际涨跌
        prev_actual = raw_prices[split_idx-1 : split_idx-1+n_points].reshape(-1, 1)
        actual_diff = curr_actual - prev_actual
        pred_diff = pred_prices - prev_actual
        
        trend_acc = np.mean(np.sign(actual_diff) == np.sign(pred_diff))
        
        # 覆盖率 (95% CI)
        lower = pred_prices - 1.96 * sigma_aligned.reshape(-1, 1)
        upper = pred_prices + 1.96 * sigma_aligned.reshape(-1, 1)
        coverage = np.mean((curr_actual >= lower) & (curr_actual <= upper))
        
        # 7. 绘图 (只画测试集)
        ax.plot(curr_indices, curr_actual, color='black', alpha=0.6, linewidth=1.5, label='Actual')
        ax.plot(curr_indices, pred_prices, color=conf['color'], linestyle='--', linewidth=1.5, label='Pred')
        ax.fill_between(curr_indices, lower.flatten(), upper.flatten(), color=conf['color'], alpha=0.1)
        
        # 文本框指标
        stats_text = (f"RMSE: {rmse:.2f}\n"
                      f"Trend: {trend_acc:.1%}\n"
                      f"Cov: {coverage:.1%}")
        
        ax.text(0.02, 0.96, stats_text, transform=ax.transAxes, verticalalignment='top',
                fontsize=11, fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.3', facecolor='white', alpha=0.9, edgecolor='gray'))
        
        ax.set_title(conf['name'], fontsize=14, fontweight='bold')
        ax.grid(True, linestyle=':', alpha=0.5)
        ax.legend(loc='lower right', fontsize=10)
        
    plt.suptitle(f"Model Comparison on Test Set: {base_name}", fontsize=18, y=0.95)
    
    # 调整布局
    plt.tight_layout(rect=[0, 0, 1, 0.95])
    
    save_path = f"{base_name}_4models_test_only.png"
    plt.savefig(save_path, dpi=300)
    plt.close()
    print(f"绘图完成，已保存至: {save_path}")

if __name__ == "__main__":
    files = glob.glob("*.csv")
    for f in files:
        run_four_models_comparison(f)