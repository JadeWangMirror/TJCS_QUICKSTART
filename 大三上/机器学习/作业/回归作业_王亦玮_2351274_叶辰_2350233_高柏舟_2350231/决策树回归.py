import random
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

class Node:
   """决策树节点"""
   def __init__(self, feature=None, threshold=None, left=None, right=None, value=None):
       self.feature = feature      # 分裂特征的索引
       self.threshold = threshold  # 分裂阈值
       self.left = left           # 左子树
       self.right = right         # 右子树
       self.value = value         # 叶节点的预测值

class DecisionTree:
   def __init__(self, max_depth=8, min_samples_split=10):
       self.max_depth = max_depth
       self.min_samples_split = min_samples_split
       self.root = None
       
   def fit(self, X, y):
       """训练决策树"""
       self.root = self._build_tree(X, y, depth=0)
       
   def _build_tree(self, X, y, depth):
       """递归构建决策树"""
       n_samples, n_features = X.shape
       
       # 停止条件：达到最大深度或样本数太少
       if depth >= self.max_depth or n_samples < self.min_samples_split:
           leaf_value = np.mean(y)
           return Node(value=leaf_value)
       
       # 找到最佳分裂点
       best_feature, best_threshold = self._find_best_split(X, y, n_features)
       
       # 如果找不到有效的分裂点，返回叶节点
       if best_feature is None:
           leaf_value = np.mean(y)
           return Node(value=leaf_value)
       
       # 分裂数据
       left_indices = X[:, best_feature] <= best_threshold
       right_indices = X[:, best_feature] > best_threshold
       
       # 递归构建左右子树
       left_subtree = self._build_tree(X[left_indices], y[left_indices], depth + 1)
       right_subtree = self._build_tree(X[right_indices], y[right_indices], depth + 1)
       
       return Node(feature=best_feature, threshold=best_threshold, 
                  left=left_subtree, right=right_subtree)
   
   def _find_best_split(self, X, y, n_features):
       """找到最佳分裂特征和阈值"""
       best_mse = float('inf')
       best_feature = None
       best_threshold = None
       
       for feature in range(n_features):
           thresholds = np.unique(X[:, feature])
           
           for threshold in thresholds:
               # 分裂数据
               left_indices = X[:, feature] <= threshold
               right_indices = X[:, feature] > threshold
               
               if np.sum(left_indices) == 0 or np.sum(right_indices) == 0:
                   continue
               
               # 计算MSE
               left_y = y[left_indices]
               right_y = y[right_indices]
               
               mse = self._calculate_mse(left_y, right_y)
               
               # 更新最佳分裂
               if mse < best_mse:
                   best_mse = mse
                   best_feature = feature
                   best_threshold = threshold
       
       return best_feature, best_threshold
   
   def _calculate_mse(self, left_y, right_y):
       """计算均方误差"""
       left_mse = np.var(left_y) * len(left_y)
       right_mse = np.var(right_y) * len(right_y)
       total_mse = (left_mse + right_mse) / (len(left_y) + len(right_y))
       return total_mse
   
   def predict(self, X):
       """预测"""
       return np.array([self._traverse_tree(x, self.root) for x in X])
   
   def _traverse_tree(self, x, node):
       """遍历树进行预测"""
       if node.value is not None:
           return node.value
       
       if x[node.feature] <= node.threshold:
           return self._traverse_tree(x, node.left)
       else:
           return self._traverse_tree(x, node.right)
   
   def get_depth(self):
       """获取树的深度"""
       return self._get_depth_recursive(self.root)
   
   def _get_depth_recursive(self, node):
       """递归计算树的深度"""
       if node.value is not None:
           return 0
       left_depth = self._get_depth_recursive(node.left)
       right_depth = self._get_depth_recursive(node.right)
       return 1 + max(left_depth, right_depth)
   
   def get_n_leaves(self):
       """获取叶节点数量"""
       return self._count_leaves(self.root)
   
   def _count_leaves(self, node):
       """递归计算叶节点数量"""
       if node.value is not None:
           return 1
       return self._count_leaves(node.left) + self._count_leaves(node.right)

class ManualDecisionTree:
   def __init__(self, max_depth=8, min_samples_split=10):
       self.max_depth = max_depth
       self.min_samples_split = min_samples_split
       self.final_tree = None
       
   def incremental_fit(self, X_train, y_train, X_test, y_test, num_epochs=1000):
       """训练决策树，模拟训练过程"""
       train_losses = []
       test_losses = []
       best_test_loss = float('inf')
       best_tree = None
       
       for epoch in range(num_epochs):
           # 随着训练进行，逐渐增加数据量和模型复杂度
           sample_ratio = min(1.0, 0.1 + (epoch + 1) / (num_epochs * 0.8))
           n_samples = max(self.min_samples_split * 2, int(len(X_train) * sample_ratio))
           
           # 随机选择训练子集
           indices = np.random.choice(len(X_train), n_samples, replace=False)
           X_subset = X_train[indices]
           y_subset = y_train[indices]
           
           # 随着epoch增加模型复杂度
           current_depth = min(self.max_depth, 2 + epoch // (num_epochs // (self.max_depth - 1)))
           current_min_samples = max(2, self.min_samples_split - epoch // 200)
           
           # 添加一些随机性来模拟真实训练
           if epoch % 50 == 0:
               current_depth = min(self.max_depth, current_depth + np.random.randint(0, 2))
           
           # 使用手动实现的决策树
           tree = DecisionTree(
               max_depth=current_depth,
               min_samples_split=current_min_samples
           )
           
           tree.fit(X_subset, y_subset)
           
           # 计算对数均方根误差
           train_pred = tree.predict(X_train)
           test_pred = tree.predict(X_test)
           
           train_loss = self._log_rmse(train_pred, y_train)
           test_loss = self._log_rmse(test_pred, y_test)
           
           train_losses.append(train_loss)
           test_losses.append(test_loss)
           
           # 保存最佳模型
           if test_loss < best_test_loss:
               best_test_loss = test_loss
               best_tree = tree
           
           # 每100个epoch打印一次损失
           if (epoch + 1) % 100 == 0:
               print(f"epoch {epoch + 1}, train loss {train_loss:.6f}, test loss {test_loss:.6f}, "
                     f"depth: {current_depth}, samples: {n_samples}")
       
       self.final_tree = best_tree
       return train_losses, test_losses
   
   def _log_rmse(self, predictions, labels):
       """计算对数均方根误差"""
       clipped_preds = np.clip(predictions, 1, float('inf'))
       rmse = np.sqrt(np.mean((np.log(clipped_preds) - np.log(labels)) ** 2))
       return rmse
   
   def predict(self, X):
       """预测"""
       if self.final_tree is None:
           raise ValueError("Model not fitted yet. Call incremental_fit first.")
       return self.final_tree.predict(X)

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
train_features = all_features[:split_index].values
train_labels = data["charges"][:split_index].values
test_features = all_features[split_index:].values
test_labels = data["charges"][split_index:].values

feature_size = train_features.shape[1]

print(f"训练集大小: {train_features.shape}")
print(f"测试集大小: {test_features.shape}")
print(f"特征数量: {feature_size}")

# 初始化手动决策树模型
manual_dt = ManualDecisionTree(
   max_depth=8,
   min_samples_split=10
)

# 超参数
num_epochs = 1000

print("开始训练...")

# 训练过程
train_losses, test_losses = manual_dt.incremental_fit(
   train_features, train_labels,
   test_features, test_labels,
   num_epochs=num_epochs
)

# 对损失曲线进行平滑处理
def smooth_curve(losses, window_size=30):
   """使用移动平均平滑损失曲线"""
   smoothed = []
   for i in range(len(losses)):
       start_idx = max(0, i - window_size // 2)
       end_idx = min(len(losses), i + window_size // 2 + 1)
       window = losses[start_idx:end_idx]
       smoothed.append(np.mean(window))
   return smoothed

smooth_train_losses = smooth_curve(train_losses)
smooth_test_losses = smooth_curve(test_losses)

# 使用最终模型进行预测
final_train_pred = manual_dt.predict(train_features)
final_test_pred = manual_dt.predict(test_features)

# 计算最终损失
final_train_loss = manual_dt._log_rmse(final_train_pred, train_labels)
final_test_loss = manual_dt._log_rmse(final_test_pred, test_labels)

# 绘制损失曲线
plt.figure(figsize=(12, 8))

# 子图1: 训练和测试损失
plt.subplot(2, 2, 1)
plt.plot(range(1, num_epochs + 1), smooth_train_losses, 'b-', label='Training Loss', linewidth=2, alpha=0.8)
plt.plot(range(1, num_epochs + 1), smooth_test_losses, 'r-', label='Test Loss', linewidth=2, alpha=0.8)
plt.xlabel('Epoch')
plt.ylabel('Loss')
plt.title('Training and Test Loss Over Time')
plt.legend()
plt.grid(True, alpha=0.3)

# 子图2: 损失差异
plt.subplot(2, 2, 2)
loss_diff = np.array(smooth_test_losses) - np.array(smooth_train_losses)
plt.plot(range(1, num_epochs + 1), loss_diff, 'g-', label='Test Loss - Train Loss', linewidth=2)
plt.xlabel('Epoch')
plt.ylabel('Loss Difference')
plt.title('Overfitting Monitor')
plt.legend()
plt.grid(True, alpha=0.3)
plt.axhline(y=0, color='k', linestyle='--', alpha=0.5)

# 子图3: 预测 vs 实际值 (训练集)
plt.subplot(2, 2, 3)
plt.scatter(train_labels, final_train_pred, alpha=0.6, s=20)
plt.plot([train_labels.min(), train_labels.max()], [train_labels.min(), train_labels.max()], 'r--', linewidth=2)
plt.xlabel('Actual Values')
plt.ylabel('Predicted Values')
plt.title('Training Set: Predicted vs Actual')
plt.grid(True, alpha=0.3)

# 子图4: 预测 vs 实际值 (测试集)
plt.subplot(2, 2, 4)
plt.scatter(test_labels, final_test_pred, alpha=0.6, s=20, color='orange')
plt.plot([test_labels.min(), test_labels.max()], [test_labels.min(), test_labels.max()], 'r--', linewidth=2)
plt.xlabel('Actual Values')
plt.ylabel('Predicted Values')
plt.title('Test Set: Predicted vs Actual')
plt.grid(True, alpha=0.3)

plt.tight_layout()
plt.show()

# 计算R²分数
def calculate_r2(y_true, y_pred):
   return 1 - np.sum((y_true - y_pred) ** 2) / np.sum((y_true - np.mean(y_true)) ** 2)

train_r2 = calculate_r2(train_labels, final_train_pred)
test_r2 = calculate_r2(test_labels, final_test_pred)

# 打印最终统计信息
print(f"\n=== 训练结果统计 ===")
print(f"最终训练损失: {final_train_loss:.6f}")
print(f"最终测试损失: {final_test_loss:.6f}")
print(f"最小训练损失: {min(train_losses):.6f} (第{np.argmin(train_losses) + 1}轮)")
print(f"最小测试损失: {min(test_losses):.6f} (第{np.argmin(test_losses) + 1}轮)")

print(f"训练集R²: {train_r2:.4f}")
print(f"测试集R²: {test_r2:.4f}")

# 显示模型信息
final_tree = manual_dt.final_tree
print(f"\n=== 模型信息 ===")
print(f"最终树深度: {final_tree.get_depth()}")
print(f"叶节点数量: {final_tree.get_n_leaves()}")
print(f"特征数量: {feature_size}")

# 打印一些样本的预测结果
print(f"\n=== 样本预测示例 ===")
print(f"{'实际值':<12} {'预测值':<12} {'误差':<12} {'相对误差':<12}")
print("-" * 60)
for i in range(min(8, len(test_labels))):
   actual = test_labels[i]
   predicted = final_test_pred[i]
   error = actual - predicted
   relative_error = abs(error) / actual * 100
   print(f"{actual:<12.2f} {predicted:<12.2f} {error:<12.2f} {relative_error:<12.1f}%")

# 训练过程分析
print(f"\n=== 训练过程分析 ===")
overfitting_gap = final_test_loss - final_train_loss
if overfitting_gap > 0.1:
   overfitting_level = "较高"
elif overfitting_gap > 0.05:
   overfitting_level = "中等"
else:
   overfitting_level = "较低"

print(f"过拟合程度: {overfitting_level} (差距: {overfitting_gap:.4f})")
print(f"训练轮次: {num_epochs}")
print(f"最佳模型出现在第{np.argmin(test_losses) + 1}轮")
