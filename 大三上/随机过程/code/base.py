import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.gaussian_process import GaussianProcessRegressor
from sklearn.gaussian_process.kernels import RBF, ConstantKernel as C, WhiteKernel
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error
import os
import glob

def run_final_model_test(file_path):
    base_name = os.path.splitext(os.path.basename(file_path))[0]
    print(f"正在处理文件: {file_path}")
    
    try:
        # 1. 数据加载与清洗
        df = pd.read_csv(file_path)
        df['Date'] = pd.to_datetime(df['Date'])
        df = df.sort_values('Date').reset_index(drop=True)
        
        # 自动获取价格列
        price_col = 'Close/Last' if 'Close/Last' in df.columns else 'Close'
        if df[price_col].dtype == object:
            df[price_col] = df[price_col].str.replace('$', '').str.replace(',', '').astype(float)
        
        raw_prices = df[price_col].values
        
        # 2. 特征工程：差分处理 (确保预测目标是变化量，消除非平稳性)
        diff_data = np.diff(raw_prices)
        
        window_size = 10
        train_ratio = 0.85
        
        X, y = [], []
        for i in range(window_size, len(diff_data)):
            # 特征：过去 window_size 天的差分
            X.append(diff_data[i-window_size:i])
            # 标签：当天的差分（即预测相对于昨天的价格变化）
            y.append(diff_data[i])
        
        X = np.array(X)
        y = np.array(y).reshape(-1, 1)
        
        # 3. 时间序列分割
        train_size = int(len(X) * train_ratio)
        X_train, X_test = X[:train_size], X[train_size:]
        y_train, y_test = y[:train_size], y[train_size:]
        
        # 4. 标准化 (仅参考训练集，严防未来信息泄露)
        # 采样训练以平衡计算效率
        sample_idx = np.arange(0, len(X_train), 10)
        scaler_X = StandardScaler().fit(X_train[sample_idx])
        scaler_y = StandardScaler().fit(y_train[sample_idx])
        
        X_train_scaled = scaler_X.transform(X_train[sample_idx])
        y_train_scaled = scaler_y.transform(y_train[sample_idx])
        X_test_scaled = scaler_X.transform(X_test)
        
        # 5. GPR 建模
        kernel = C(1.0) * RBF(length_scale=2.0) + WhiteKernel(noise_level=0.1)
        gp = GaussianProcessRegressor(kernel=kernel, n_restarts_optimizer=5, random_state=42)
        gp.fit(X_train_scaled, y_train_scaled)
        
        # 6. 预测差分值及其不确定度
        y_pred_diff_scaled, sigma_scaled = gp.predict(X_test_scaled, return_std=True)
        y_pred_diff = scaler_y.inverse_transform(y_pred_diff_scaled.reshape(-1, 1))
        # 还原标准差到原始量级
        sigma = (sigma_scaled * scaler_y.scale_[0]).reshape(-1, 1)
        
        # 7. 还原预测价格 (核心逻辑：价格_t+1 = 价格_t + 预测变化量_t+1)
        # base_prices 为测试集每一天预测时的“已知昨日价格”
        base_price_idx = train_size + window_size
        base_prices = raw_prices[base_price_idx : base_price_idx + len(y_pred_diff)].reshape(-1, 1)
        
        y_pred_price = base_prices + y_pred_diff
        actual_prices = raw_prices[base_price_idx + 1 : base_price_idx + 1 + len(y_pred_diff)].reshape(-1, 1)
        
        # 8. 指标计算
        # A. RMSE (均方根误差)
        rmse = np.sqrt(mean_squared_error(actual_prices, y_pred_price))
        
        # B. 落在上下界中的概率 (Coverage Probability)
        # 这里定义上下界为 95% 置信区间 (1.96 * sigma)
        lower_bound = y_pred_price - 1.96 * sigma
        upper_bound = y_pred_price + 1.96 * sigma
        in_bounds = (actual_prices >= lower_bound) & (actual_prices <= upper_bound)
        coverage_prob = np.mean(in_bounds)
        
        # C. 趋势正确率 (Trend Accuracy)
        actual_move = actual_prices - base_prices
        trend_correct = (np.sign(actual_move) == np.sign(y_pred_diff))
        trend_accuracy = np.mean(trend_correct)
        
        # 9. 绘图与结果展示
        plt.figure(figsize=(15, 8))
        time_axis = np.arange(len(y_pred_price))
        
        plt.plot(time_axis, actual_prices, color='black', label='Actual Price', alpha=0.7)
        plt.plot(time_axis, y_pred_price, color='red', linestyle='--', label='GPR Prediction')
        plt.fill_between(time_axis, lower_bound.flatten(), upper_bound.flatten(), 
                         color='blue', alpha=0.15, label='95% Confidence Interval')
        
        # 在图中打印关键数据指标
        stats_box = (
            f"Model Performance Metrics\n"
            f"--------------------------\n"
            f"RMSE: {rmse:.4f}\n"
            f"Trend Accuracy: {trend_accuracy:.2%}\n"
            f"In-Bounds Probability: {coverage_prob:.2%}"
        )
        
        # 放置文本框
        plt.text(0.02, 0.96, stats_box, transform=plt.gca().transAxes, fontsize=11,
                 verticalalignment='top', family='monospace',
                 bbox=dict(boxstyle='round,pad=0.5', facecolor='white', alpha=0.9, edgecolor='navy'))

        plt.title(f"GPR Backtest: {base_name}", fontsize=14)
        plt.xlabel("Days (Test Set Period)")
        plt.ylabel("Price")
        plt.legend(loc='lower left')
        plt.grid(True, linestyle=':', alpha=0.5)
        
        plt.savefig(f"{base_name}_final_model_test.png", dpi=300)
        plt.close()
        print(f"处理完成！指标：准确率 {trend_accuracy:.2%}, 覆盖率 {coverage_prob:.2%}")

    except Exception as e:
        print(f"处理过程中出错: {e}")

if __name__ == "__main__":
    for f in glob.glob("*.csv"):
        run_final_model_test(f)