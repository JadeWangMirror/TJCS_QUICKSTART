import random
import torch
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np


# ==================== 基础模型函数 ====================
def linreg(X, w, b):
    """线性回归模型"""
    return torch.matmul(X, w) + b


def squared_loss(y_hat, y):
    """均方损失"""
    return (y_hat - y.reshape(y_hat.shape)) ** 2 / 2


def sgd(params, lr, batch_size):
    """小批量随机梯度下降"""
    with torch.no_grad():
        for param in params:
            param -= lr * param.grad / batch_size
            param.grad.zero_()


def data_iter(batch_size, features, labels):
    """数据迭代器"""
    num_examples = len(features)
    indices = list(range(num_examples))
    random.shuffle(indices)
    for i in range(0, num_examples, batch_size):
        batch_indices = torch.tensor(indices[i: min(i + batch_size, num_examples)])
        yield features[batch_indices], labels[batch_indices]


# ==================== 正则化损失函数 ====================
def l2_penalty(w):
    """L2正则化惩罚项"""
    return torch.sum(w ** 2) / 2


def l1_penalty(w):
    """L1正则化惩罚项"""
    return torch.sum(torch.abs(w))


def regularized_loss(y_hat, y, w, reg_type='none', lambda_param=0, alpha=0.5):
    """
    正则化损失函数

    参数:
        y_hat: 预测值
        y: 真实值
        w: 权重参数
        reg_type: 正则化类型 ('none', 'ridge', 'lasso', 'elastic')
        lambda_param: 正则化强度
        alpha: Elastic Net中L1的比例 (0-1之间)
    """
    base_loss = squared_loss(y_hat, y).mean()

    if reg_type == 'none' or lambda_param == 0:
        return base_loss
    elif reg_type == 'ridge':
        return base_loss + lambda_param * l2_penalty(w)
    elif reg_type == 'lasso':
        return base_loss + lambda_param * l1_penalty(w)
    elif reg_type == 'elastic':
        return base_loss + lambda_param * (alpha * l1_penalty(w) + (1 - alpha) * l2_penalty(w))
    else:
        raise ValueError(f"Unknown regularization type: {reg_type}")


# ==================== 评估指标 ====================
def log_rmse(y_pred, y_true):
    """对数均方根误差"""
    clipped_preds = torch.clamp(y_pred, 1, float('inf'))
    rmse = torch.sqrt(((torch.log(clipped_preds) - torch.log(y_true)) ** 2).mean())
    return rmse.item()


def mse(y_pred, y_true):
    """均方误差"""
    return ((y_pred - y_true) ** 2).mean().item()


def mae(y_pred, y_true):
    """平均绝对误差"""
    return torch.abs(y_pred - y_true).mean().item()


def r2_score(y_pred, y_true):
    """R²分数"""
    ss_res = torch.sum((y_true - y_pred) ** 2)
    ss_tot = torch.sum((y_true - y_true.mean()) ** 2)
    return (1 - ss_res / ss_tot).item()


# ==================== K折交叉验证 ====================
def get_k_fold_data(k, i, X, y):
    """获取第i折的训练集和验证集"""
    assert k > 1
    fold_size = X.shape[0] // k
    X_train, y_train = None, None
    for j in range(k):
        idx = slice(j * fold_size, (j + 1) * fold_size)
        X_part, y_part = X[idx, :], y[idx]
        if j == i:
            X_valid, y_valid = X_part, y_part
        elif X_train is None:
            X_train, y_train = X_part, y_part
        else:
            X_train = torch.cat([X_train, X_part], 0)
            y_train = torch.cat([y_train, y_part], 0)
    return X_train, y_train, X_valid, y_valid


def train_model(X_train, y_train, X_valid, y_valid, feature_size,
                num_epochs, lr, batch_size, reg_type, lambda_param, alpha=0.5, verbose=False):
    """
    训练模型（统一的训练函数）

    参数:
        X_train, y_train: 训练数据
        X_valid, y_valid: 验证数据（如果为None则不计算验证损失）
        verbose: 是否打印训练过程
        其他: 模型超参数

    返回:
        w, b: 训练好的参数
        train_losses: 训练损失历史
        valid_losses: 验证损失历史（如果没有验证集则为None）
    """
    # 初始化参数
    w = torch.normal(0, 0.01, size=(feature_size, 1), requires_grad=True)
    b = torch.zeros(1, requires_grad=True)

    train_losses = []
    valid_losses = [] if X_valid is not None else None

    for epoch in range(num_epochs):
        # 训练
        for X, y in data_iter(batch_size, X_train, y_train):
            l = regularized_loss(linreg(X, w, b), y, w, reg_type, lambda_param, alpha)
            l.backward()
            sgd([w, b], lr, batch_size)

        # 评估
        with torch.no_grad():
            train_pred = linreg(X_train, w, b)
            train_losses.append(log_rmse(train_pred, y_train))

            if X_valid is not None:
                valid_pred = linreg(X_valid, w, b)
                valid_losses.append(log_rmse(valid_pred, y_valid))

        # 打印训练过程
        if verbose and (epoch + 1) % 20 == 0:
            if X_valid is not None:
                print(
                    f"Epoch {epoch + 1}/{num_epochs}, train loss: {train_losses[-1]:.6f}, valid loss: {valid_losses[-1]:.6f}")
            else:
                print(f"Epoch {epoch + 1}/{num_epochs}, train loss: {train_losses[-1]:.6f}")

    return w.detach(), b.detach(), train_losses, valid_losses


def k_fold_cross_validation(k, X_train, y_train, feature_size,
                            num_epochs, lr, batch_size,
                            reg_type, lambda_param, alpha=0.5, verbose=True):
    """
    K折交叉验证

    返回:
        avg_train_loss: 平均训练损失
        avg_valid_loss: 平均验证损失
        all_valid_losses: 所有折的验证损失历史（用于分析）
    """
    train_loss_sum = 0
    valid_loss_sum = 0
    all_valid_losses = []

    for i in range(k):
        X_tr, y_tr, X_val, y_val = get_k_fold_data(k, i, X_train, y_train)

        # 使用统一的训练函数
        w, b, train_losses, valid_losses = train_model(
            X_tr, y_tr, X_val, y_val, feature_size,
            num_epochs, lr, batch_size, reg_type, lambda_param, alpha, verbose=False
        )

        train_loss_sum += train_losses[-1]
        valid_loss_sum += valid_losses[-1]
        all_valid_losses.append(valid_losses)

        if verbose:
            print(f'折 {i + 1}/{k}, 训练log rmse: {train_losses[-1]:.6f}, '
                  f'验证log rmse: {valid_losses[-1]:.6f}')

    avg_train_loss = train_loss_sum / k
    avg_valid_loss = valid_loss_sum / k

    return avg_train_loss, avg_valid_loss, all_valid_losses


# ==================== 超参数搜索 ====================
def grid_search(X_train, y_train, feature_size, k_folds,
                num_epochs, lr, batch_size,
                reg_type, lambda_values, alpha_values=None):
    """
    网格搜索最佳超参数

    参数:
        lambda_values: lambda参数候选值列表
        alpha_values: alpha参数候选值列表（仅用于Elastic Net）

    返回:
        best_params: 最佳参数字典
        results: 所有结果列表
    """
    results = []
    best_valid_loss = float('inf')
    best_params = {}

    # 确定要搜索的参数组合
    if reg_type == 'elastic' and alpha_values is not None:
        param_combinations = [(lam, alpha) for lam in lambda_values for alpha in alpha_values]
    else:
        param_combinations = [(lam, 0.5) for lam in lambda_values]

    print(f"\n{'=' * 60}")
    print(f"开始 {reg_type.upper()} 网格搜索")
    print(f"{'=' * 60}")

    for idx, (lambda_param, alpha) in enumerate(param_combinations, 1):
        if reg_type == 'elastic':
            print(f"\n[{idx}/{len(param_combinations)}] 测试 lambda={lambda_param:.6f}, alpha={alpha:.3f}")
        else:
            print(f"\n[{idx}/{len(param_combinations)}] 测试 lambda={lambda_param:.6f}")

        avg_train_loss, avg_valid_loss, _ = k_fold_cross_validation(
            k_folds, X_train, y_train, feature_size,
            num_epochs, lr, batch_size,
            reg_type, lambda_param, alpha, verbose=False
        )

        result = {
            'lambda': lambda_param,
            'alpha': alpha,
            'train_loss': avg_train_loss,
            'valid_loss': avg_valid_loss
        }
        results.append(result)

        print(f"平均训练loss: {avg_train_loss:.6f}, 平均验证loss: {avg_valid_loss:.6f}")

        if avg_valid_loss < best_valid_loss:
            best_valid_loss = avg_valid_loss
            best_params = {'lambda': lambda_param, 'alpha': alpha}
            print(f">>> 找到更好的参数!")

    print(f"\n{'=' * 60}")
    print(f"最佳参数: lambda={best_params['lambda']:.6f}", end='')
    if reg_type == 'elastic':
        print(f", alpha={best_params['alpha']:.3f}", end='')
    print(f"\n最佳验证loss: {best_valid_loss:.6f}")
    print(f"{'=' * 60}\n")

    return best_params, results


# ==================== 模型评估 ====================
def evaluate_model(X, y, w, b, dataset_name=""):
    """评估模型性能"""
    with torch.no_grad():
        y_pred = linreg(X, w, b)

        metrics = {
            'MSE': mse(y_pred, y),
            'MAE': mae(y_pred, y),
            'R²': r2_score(y_pred, y),
            'Log RMSE': log_rmse(y_pred, y)
        }

    print(f"\n{dataset_name}性能指标:")
    print(f"  MSE:      {metrics['MSE']:.2f}")
    print(f"  MAE:      {metrics['MAE']:.2f}")
    print(f"  R²:       {metrics['R²']:.4f}")
    print(f"  Log RMSE: {metrics['Log RMSE']:.6f}")

    return metrics, y_pred


# ==================== 可视化 ====================
def plot_comparison(results_dict, test_features, test_labels):
    """
    绘制所有模型的对比图

    参数:
        results_dict: 字典，键为模型名称，值为(w, b, metrics, predictions)元组
    """
    n_models = len(results_dict)
    fig = plt.figure(figsize=(15, 4 * ((n_models + 1) // 2)))

    for idx, (model_name, (w, b, metrics, pred)) in enumerate(results_dict.items(), 1):
        plt.subplot((n_models + 1) // 2, 2, idx)
        plt.scatter(test_labels.numpy(), pred.numpy(), alpha=0.6, s=20)
        plt.plot([test_labels.min(), test_labels.max()],
                 [test_labels.min(), test_labels.max()],
                 'r--', linewidth=2)
        plt.xlabel('Actual Values')
        plt.ylabel('Predicted Values')
        plt.title(f'{model_name}\nMSE: {metrics["MSE"]:.2f}, MAE: {metrics["MAE"]:.2f}, R²: {metrics["R²"]:.4f}')
        plt.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('model_comparison.png', dpi=150, bbox_inches='tight')
    plt.show()


def plot_metrics_comparison(all_results):
    """绘制不同模型的性能指标对比"""
    models = list(all_results.keys())
    mse_values = [all_results[m][2]['MSE'] for m in models]
    mae_values = [all_results[m][2]['MAE'] for m in models]
    r2_values = [all_results[m][2]['R²'] for m in models]

    fig, axes = plt.subplots(1, 3, figsize=(15, 4))

    # MSE对比
    axes[0].bar(models, mse_values, color=['blue', 'green', 'orange', 'red'])
    axes[0].set_ylabel('MSE')
    axes[0].set_title('Mean Squared Error')
    axes[0].tick_params(axis='x', rotation=45)

    # MAE对比
    axes[1].bar(models, mae_values, color=['blue', 'green', 'orange', 'red'])
    axes[1].set_ylabel('MAE')
    axes[1].set_title('Mean Absolute Error')
    axes[1].tick_params(axis='x', rotation=45)

    # R²对比
    axes[2].bar(models, r2_values, color=['blue', 'green', 'orange', 'red'])
    axes[2].set_ylabel('R² Score')
    axes[2].set_title('R² Score')
    axes[2].tick_params(axis='x', rotation=45)

    plt.tight_layout()
    plt.savefig('metrics_comparison.png', dpi=150, bbox_inches='tight')
    plt.show()


# ==================== 主程序 ====================
if __name__ == "__main__":
    # 数据加载和预处理
    print("加载数据...")
    data = pd.read_csv('./archive/insurance.csv')
    all_features = data.drop('charges', axis=1)
    numeric_features = all_features.dtypes[all_features.dtypes != 'object'].index
    all_features[numeric_features] = (all_features[numeric_features].apply(
        lambda x: (x - x.mean()) / (x.std())))
    all_features[numeric_features] = all_features[numeric_features].fillna(0)
    all_features = pd.get_dummies(all_features, dummy_na=True)
    all_features = all_features * 1

    # 划分训练集和测试集
    test_size = 0.2
    split_index = int((1 - test_size) * len(data))
    train_features = torch.tensor(all_features[:split_index].values, dtype=torch.float32)
    train_labels = torch.tensor(data["charges"][:split_index].values.reshape(-1, 1), dtype=torch.float32)
    test_features = torch.tensor(all_features[split_index:].values, dtype=torch.float32)
    test_labels = torch.tensor(data["charges"][split_index:].values.reshape(-1, 1), dtype=torch.float32)

    feature_size = train_features.shape[1]
    print(f"训练集大小: {len(train_features)}, 测试集大小: {len(test_features)}")
    print(f"特征数量: {feature_size}")

    # 超参数设置
    k_folds = 5
    num_epochs = 300
    lr = 1
    batch_size = 30

    # 定义搜索空间
    lambda_values = [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0]
    alpha_values = [0.3, 0.5, 0.7]  # 用于Elastic Net

    # 存储所有模型结果
    all_results = {}

    # ========== 1. 普通线性回归 ==========
    print("\n" + "=" * 70)
    print("1. 普通线性回归（无正则化）")
    print("=" * 70)
    print("在全部训练数据上训练模型...")
    w_linear, b_linear, train_losses_linear, _ = train_model(
        train_features, train_labels, None, None, feature_size,
        num_epochs, lr, batch_size, 'none', 0, verbose=True
    )
    print(f"最终训练loss: {train_losses_linear[-1]:.6f}")
    metrics_linear, pred_linear = evaluate_model(test_features, test_labels, w_linear, b_linear, "测试集")
    all_results['Linear'] = (w_linear, b_linear, metrics_linear, pred_linear)

    # ========== 2. Ridge回归 ==========
    print("\n" + "=" * 70)
    print("2. Ridge回归（L2正则化）")
    print("=" * 70)
    # best_params_ridge, results_ridge = grid_search(
    #     train_features, train_labels, feature_size, k_folds,
    #     num_epochs, lr, batch_size, 'ridge', lambda_values
    # )
    lambda1=0.2
    print("在全部训练数据上训练最终模型...")
    w_ridge, b_ridge, train_losses_ridge, _ = train_model(
        train_features, train_labels, None, None, feature_size,
        num_epochs, lr, batch_size, 'ridge', lambda1, verbose=True
    )
    print(f"最终训练loss: {train_losses_ridge[-1]:.6f}")
    metrics_ridge, pred_ridge = evaluate_model(test_features, test_labels, w_ridge, b_ridge, "测试集")
    all_results['Ridge'] = (w_ridge, b_ridge, metrics_ridge, pred_ridge)

    # ========== 3. Lasso回归 ==========
    print("\n" + "=" * 70)
    print("3. Lasso回归（L1正则化）")
    print("=" * 70)
    # best_params_lasso, results_lasso = grid_search(
    #     train_features, train_labels, feature_size, k_folds,
    #     num_epochs, lr, batch_size, 'lasso', lambda_values
    # )
    lambda2 = 0.8
    print("在全部训练数据上训练最终模型...")
    w_lasso, b_lasso, train_losses_lasso, _ = train_model(
        train_features, train_labels, None, None, feature_size,
        num_epochs, lr, batch_size, 'lasso', lambda2, verbose=True
    )
    print(f"最终训练loss: {train_losses_lasso[-1]:.6f}")
    metrics_lasso, pred_lasso = evaluate_model(test_features, test_labels, w_lasso, b_lasso, "测试集")
    all_results['Lasso'] = (w_lasso, b_lasso, metrics_lasso, pred_lasso)

    # ========== 4. Elastic Net回归 ==========
    print("\n" + "=" * 70)
    print("4. Elastic Net回归（L1+L2正则化）")
    # print("=" * 70)
    # best_params_elastic, results_elastic = grid_search(
    #     train_features, train_labels, feature_size, k_folds,
    #     num_epochs, lr, batch_size, 'elastic', lambda_values, alpha_values
    # )

    lambda3=0.2
    alpha=0.3
    print("在全部训练数据上训练最终模型...")
    w_elastic, b_elastic, train_losses_elastic, _ = train_model(
        train_features, train_labels, None, None, feature_size,
        num_epochs, lr, batch_size, 'elastic',
        lambda3, alpha, verbose=True
    )
    print(f"最终训练loss: {train_losses_elastic[-1]:.6f}")
    metrics_elastic, pred_elastic = evaluate_model(test_features, test_labels, w_elastic, b_elastic, "测试集")
    all_results['Elastic Net'] = (w_elastic, b_elastic, metrics_elastic, pred_elastic)

    # ========== 结果总结 ==========
    print("\n" + "=" * 70)
    print("最终结果总结")
    print("=" * 70)
    for model_name, (w, b, metrics, _) in all_results.items():
        print(f"\n{model_name}:")
        print(f"  MSE: {metrics['MSE']:.2f}")
        print(f"  MAE: {metrics['MAE']:.2f}")
        print(f"  R²:  {metrics['R²']:.4f}")

    # 可视化
    print("\n生成可视化图表...")
    plot_comparison(all_results, test_features, test_labels)
    plot_metrics_comparison(all_results)
    print("\n完成！图表已保存。")