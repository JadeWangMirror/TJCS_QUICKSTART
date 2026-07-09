import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import torch
import torch.nn as nn
import warnings

warnings.filterwarnings('ignore')

# 设置中文显示
plt.rcParams['font.sans-serif'] = ['SimHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False


# ==================== 0. 手写评估指标 ====================

def accuracy_score(y_true, y_pred):
    """计算准确率"""
    return np.mean(y_true == y_pred)


def precision_recall_fscore_support(y_true, y_pred, average='binary'):
    """计算精确率、召回率、F1、支持度"""
    if average == 'binary':
        tp = np.sum((y_pred == 1) & (y_true == 1))
        fp = np.sum((y_pred == 1) & (y_true == 0))
        fn = np.sum((y_pred == 0) & (y_true == 1))

        precision = tp / (tp + fp + 1e-8)
        recall = tp / (tp + fn + 1e-8)
        f1 = 2 * (precision * recall) / (precision + recall + 1e-8)

        support = len(y_true)
        return precision, recall, f1, support


def confusion_matrix(y_true, y_pred):
    """计算混淆矩阵"""
    tn = np.sum((y_pred == 0) & (y_true == 0))
    fp = np.sum((y_pred == 1) & (y_true == 0))
    fn = np.sum((y_pred == 0) & (y_true == 1))
    tp = np.sum((y_pred == 1) & (y_true == 1))

    return np.array([[tn, fp], [fn, tp]])


def roc_curve(y_true, y_score):
    """计算 ROC 曲线"""
    thresholds = np.sort(np.unique(y_score))[::-1]

    fprs = []
    tprs = []

    for threshold in thresholds:
        y_pred = (y_score >= threshold).astype(int)

        tp = np.sum((y_pred == 1) & (y_true == 1))
        fp = np.sum((y_pred == 1) & (y_true == 0))
        fn = np.sum((y_pred == 0) & (y_true == 1))
        tn = np.sum((y_pred == 0) & (y_true == 0))

        fpr = fp / (fp + tn + 1e-8)
        tpr = tp / (tp + fn + 1e-8)

        fprs.append(fpr)
        tprs.append(tpr)

    return np.array(fprs), np.array(tprs), thresholds


def auc(fpr, tpr):
    """计算 AUC"""
    sorted_idx = np.argsort(fpr)
    fpr_sorted = fpr[sorted_idx]
    tpr_sorted = tpr[sorted_idx]

    auc_val = 0.0
    for i in range(len(fpr_sorted) - 1):
        auc_val += (fpr_sorted[i + 1] - fpr_sorted[i]) * (tpr_sorted[i] + tpr_sorted[i + 1]) / 2

    return auc_val


# ==================== 1. 特征工程 ====================

def feature_engineering(df):
    """
    针对 LOL 数据集进行特征工程：
    1. 构造差值特征 (Diff)
    2. 移除高相关性的冗余特征 (Red方特征)
    """
    df = df.copy()

    # --- 1. 构造更有意义的特征 ---
    df['wardsPlacedDiff'] = df['blueWardsPlaced'] - df['redWardsPlaced']
    df['wardsDestroyedDiff'] = df['blueWardsDestroyed'] - df['redWardsDestroyed']
    df['blueKDA'] = (df['blueKills'] + df['blueAssists']) / (df['blueDeaths'] + 1e-5)
    df['redKDA'] = (df['redKills'] + df['redAssists']) / (df['redDeaths'] + 1e-5)
    df['KDADiff'] = df['blueKDA'] - df['redKDA']
    df['jungleDiff'] = df['blueTotalJungleMinionsKilled'] - df['redTotalJungleMinionsKilled']
    df['eliteDiff'] = df['blueEliteMonsters'] - df['redEliteMonsters']
    df['dragonDiff'] = df['blueDragons'] - df['redDragons']
    df['heraldDiff'] = df['blueHeralds'] - df['redHeralds']

    # --- 2. 移除冗余特征 ---
    cols_to_drop = [c for c in df.columns if c.startswith('red')]
    cols_to_drop.append('gameId')
    df_clean = df.drop(columns=cols_to_drop)

    print(f"特征工程完成。特征数从 {df.shape[1]} 减少到 {df_clean.shape[1]} (去除了冗余并增加了强特征)")
    return df_clean


# ==================== 2. 手写 Softmax Regression ====================

class SoftmaxRegression(nn.Module):
    """Softmax 回归 - PyTorch 实现"""

    def __init__(self, input_dim, num_classes, learning_rate=0.01, num_epochs=20, batch_size=256, l2_lambda=2e-3):
        super().__init__()
        self.learning_rate = learning_rate
        self.num_epochs = num_epochs
        self.batch_size = batch_size
        self.l2_lambda = l2_lambda

        self.linear = nn.Linear(input_dim, num_classes)
        self.train_losses = []
        self.train_accs = []
        self.test_accs = []

    def forward(self, X):
        return self.linear(X)

    def fit(self, X_train, y_train, X_test, y_test):
        """训练"""
        X_train = torch.FloatTensor(X_train)
        y_train = torch.LongTensor(y_train)
        X_test = torch.FloatTensor(X_test)
        y_test = torch.LongTensor(y_test)

        optimizer = torch.optim.Adam(self.parameters(), lr=self.learning_rate, weight_decay=self.l2_lambda)
        criterion = nn.CrossEntropyLoss()

        print(f"\n[Softmax] 开始训练 {self.num_epochs} 个 Epoch...")

        for epoch in range(self.num_epochs):
            indices = torch.randperm(len(X_train))
            epoch_loss = 0
            epoch_acc = 0
            num_batches = 0

            for i in range(0, len(X_train), self.batch_size):
                batch_indices = indices[i:i + self.batch_size]
                X_batch = X_train[batch_indices]
                y_batch = y_train[batch_indices]

                optimizer.zero_grad()
                logits = self.forward(X_batch)
                loss = criterion(logits, y_batch)
                loss.backward()
                optimizer.step()

                epoch_loss += loss.item()
                with torch.no_grad():
                    preds = logits.argmax(dim=1)
                    acc = (preds == y_batch).float().mean().item()
                    epoch_acc += acc
                num_batches += 1

            train_loss = epoch_loss / num_batches
            train_acc = epoch_acc / num_batches

            # 测试集评估
            with torch.no_grad():
                test_logits = self.forward(X_test)
                test_preds = test_logits.argmax(dim=1)
                test_acc = (test_preds == y_test).float().mean().item()

            self.train_losses.append(train_loss)
            self.train_accs.append(train_acc)
            self.test_accs.append(test_acc)

            if (epoch + 1) % 5 == 0 or epoch == 0:
                print(
                    f"[Softmax] Epoch {epoch + 1}/{self.num_epochs}: Loss={train_loss:.4f}, Train Acc={train_acc:.4f}, Test Acc={test_acc:.4f}")

        print("[Softmax] 训练完成！")

    def predict(self, X):
        self.eval()
        with torch.no_grad():
            X = torch.FloatTensor(X)
            logits = self.forward(X)
            return logits.argmax(dim=1).numpy()

    def predict_proba(self, X):
        self.eval()
        with torch.no_grad():
            X = torch.FloatTensor(X)
            logits = self.forward(X)
            return torch.softmax(logits, dim=1).numpy()


# ==================== 3. 手写 Logistic Regression ====================

class LogisticRegressionWrapper:
    """Logistic Regression 包装器 - 手写实现"""

    def __init__(self, max_iter=1000, learning_rate=0.01, random_state=42):
        self.max_iter = max_iter
        self.learning_rate = learning_rate
        self.random_state = random_state
        self.weights = None
        self.bias = None

    def _sigmoid(self, z):
        return 1.0 / (1.0 + np.exp(-np.clip(z, -500, 500)))

    def fit(self, X_train, y_train, X_test, y_test):
        """训练"""
        print(f"\n[Logistic Regression] 开始训练...")
        n_samples, n_features = X_train.shape

        # 初始化权重和偏置
        self.weights = np.zeros(n_features)
        self.bias = 0.0

        # 梯度下降
        for iteration in range(self.max_iter):
            # 预测
            z = np.dot(X_train, self.weights) + self.bias
            predictions = self._sigmoid(z)

            # 计算损失
            loss = -np.mean(y_train * np.log(predictions + 1e-8) + (1 - y_train) * np.log(1 - predictions + 1e-8))

            # 计算梯度
            dw = (1 / n_samples) * np.dot(X_train.T, (predictions - y_train))
            db = (1 / n_samples) * np.sum(predictions - y_train)

            # 更新权重
            self.weights -= self.learning_rate * dw
            self.bias -= self.learning_rate * db

        # 计算准确率
        train_pred = self.predict(X_train)
        train_acc = accuracy_score(y_train, train_pred)

        test_pred = self.predict(X_test)
        test_acc = accuracy_score(y_test, test_pred)

        print(f"[Logistic Regression] 训练完成！Train Acc={train_acc:.4f}, Test Acc={test_acc:.4f}")

    def predict(self, X):
        z = np.dot(X, self.weights) + self.bias
        predictions = self._sigmoid(z)
        return (predictions > 0.5).astype(int)

    def predict_proba(self, X):
        z = np.dot(X, self.weights) + self.bias
        predictions = self._sigmoid(z)
        return np.column_stack([1 - predictions, predictions])


# ==================== 4. 手写 Decision Tree ====================

class DecisionTreeNode:
    """决策树节点"""

    def __init__(self, feature=None, threshold=None, left=None, right=None, value=None):
        self.feature = feature
        self.threshold = threshold
        self.left = left
        self.right = right
        self.value = value

    def is_leaf(self):
        return self.value is not None


class DecisionTreeClassifier:
    """手写决策树分类器"""

    def __init__(self, max_depth=10, min_samples_split=10, min_samples_leaf=5):
        self.max_depth = max_depth
        self.min_samples_split = min_samples_split
        self.min_samples_leaf = min_samples_leaf
        self.tree = None

    def fit(self, X, y):
        """构建决策树"""
        self.tree = self._build_tree(X, y, depth=0)
        return self

    def _build_tree(self, X, y, depth):
        n_samples, n_features = X.shape
        n_classes = len(np.unique(y))

        # 停止条件
        if (depth >= self.max_depth or
                n_samples < self.min_samples_split or
                n_classes == 1):
            leaf_value = np.argmax(np.bincount(y))
            return DecisionTreeNode(value=leaf_value)

        best_split = None
        best_gain = -float('inf')

        # 遍历所有特征和阈值
        for feature in range(n_features):
            thresholds = np.unique(X[:, feature])

            for threshold in thresholds:
                # 分割数据
                left_mask = X[:, feature] <= threshold
                right_mask = ~left_mask

                if np.sum(left_mask) < self.min_samples_leaf or np.sum(right_mask) < self.min_samples_leaf:
                    continue

                # 计算信息增益
                parent_entropy = self._entropy(y)

                n_left = np.sum(left_mask)
                n_right = np.sum(right_mask)

                left_entropy = self._entropy(y[left_mask])
                right_entropy = self._entropy(y[right_mask])

                weighted_entropy = (n_left / n_samples) * left_entropy + (n_right / n_samples) * right_entropy
                gain = parent_entropy - weighted_entropy

                if gain > best_gain:
                    best_gain = gain
                    best_split = (feature, threshold, left_mask, right_mask)

        if best_split is None:
            leaf_value = np.argmax(np.bincount(y))
            return DecisionTreeNode(value=leaf_value)

        feature, threshold, left_mask, right_mask = best_split
        left_tree = self._build_tree(X[left_mask], y[left_mask], depth + 1)
        right_tree = self._build_tree(X[right_mask], y[right_mask], depth + 1)

        return DecisionTreeNode(feature=feature, threshold=threshold, left=left_tree, right=right_tree)

    def _entropy(self, y):
        """计算熵"""
        proportions = np.bincount(y) / len(y)
        entropy = -np.sum([p * np.log2(p + 1e-8) for p in proportions if p > 0])
        return entropy

    def predict(self, X):
        """预测"""
        return np.array([self._traverse_tree(x, self.tree) for x in X])

    def _traverse_tree(self, x, node):
        """遍历树"""
        if node.is_leaf():
            return node.value

        if x[node.feature] <= node.threshold:
            return self._traverse_tree(x, node.left)
        else:
            return self._traverse_tree(x, node.right)

    def score(self, X, y):
        """计算准确率"""
        predictions = self.predict(X)
        return accuracy_score(y, predictions)

    def predict_proba(self, X):
        """返回概率（简化版）"""
        preds = self.predict(X)
        n_samples = X.shape[0]
        proba = np.zeros((n_samples, 2))
        proba[np.arange(n_samples), preds] = 1.0
        return proba


class DecisionTreeWrapper:
    """Decision Tree 包装器"""

    def __init__(self, max_depth=10, min_samples_split=10, min_samples_leaf=5, random_state=42):
        self.model = DecisionTreeClassifier(
            max_depth=max_depth,
            min_samples_split=min_samples_split,
            min_samples_leaf=min_samples_leaf
        )
        self.train_accs = []
        self.test_accs = []

    def fit(self, X_train, y_train, X_test, y_test):
        """训练"""
        print(f"\n[Decision Tree] 开始训练...")
        self.model.fit(X_train, y_train)
        train_acc = self.model.score(X_train, y_train)
        test_acc = self.model.score(X_test, y_test)

        self.train_accs.append(train_acc)
        self.test_accs.append(test_acc)

        print(f"[Decision Tree] 训练完成！Train Acc={train_acc:.4f}, Test Acc={test_acc:.4f}")

    def predict(self, X):
        return self.model.predict(X)

    def predict_proba(self, X):
        return self.model.predict_proba(X)


# ==================== 5. 手写 Random Forest ====================

class RandomForestClassifier:
    """手写 Random Forest 分类器"""

    def __init__(self, n_estimators=50, max_depth=8, min_samples_split=10, random_state=42):
        self.n_estimators = n_estimators
        self.max_depth = max_depth
        self.min_samples_split = min_samples_split
        self.random_state = random_state
        self.trees = []

    def fit(self, X, y):
        """训练随机森林"""
        np.random.seed(self.random_state)

        for _ in range(self.n_estimators):
            # Bootstrap 采样
            indices = np.random.choice(len(X), size=len(X), replace=True)
            X_sample = X[indices]
            y_sample = y[indices]

            # 训练决策树
            tree = DecisionTreeClassifier(
                max_depth=self.max_depth,
                min_samples_split=self.min_samples_split
            )
            tree.fit(X_sample, y_sample)
            self.trees.append(tree)

        return self

    def predict(self, X):
        """预测"""
        predictions = np.array([tree.predict(X) for tree in self.trees])
        # 投票
        return np.apply_along_axis(lambda x: np.argmax(np.bincount(x)), 0, predictions)

    def score(self, X, y):
        """计算准确率"""
        predictions = self.predict(X)
        return accuracy_score(y, predictions)

    def predict_proba(self, X):
        """返回概率"""
        predictions = np.array([tree.predict(X) for tree in self.trees])
        n_samples = X.shape[0]
        proba = np.zeros((n_samples, 2))

        for i in range(n_samples):
            votes = predictions[:, i]
            proba[i, 0] = np.sum(votes == 0) / len(self.trees)
            proba[i, 1] = np.sum(votes == 1) / len(self.trees)

        return proba


class RandomForestWrapper:
    """Random Forest 包装器"""

    def __init__(self, n_estimators=50, max_depth=8, min_samples_split=10, random_state=42):
        self.model = RandomForestClassifier(
            n_estimators=n_estimators,
            max_depth=max_depth,
            min_samples_split=min_samples_split,
            random_state=random_state
        )
        self.train_accs = []
        self.test_accs = []

    def fit(self, X_train, y_train, X_test, y_test):
        """训练"""
        print(f"\n[Random Forest] 开始训练 {self.model.n_estimators} 棵树...")
        self.model.fit(X_train, y_train)
        train_acc = self.model.score(X_train, y_train)
        test_acc = self.model.score(X_test, y_test)

        self.train_accs.append(train_acc)
        self.test_accs.append(test_acc)

        print(f"[Random Forest] 训练完成！Train Acc={train_acc:.4f}, Test Acc={test_acc:.4f}")

    def predict(self, X):
        return self.model.predict(X)

    def predict_proba(self, X):
        return self.model.predict_proba(X)


# ==================== 6. 手写 XGBoost ====================

class XGBTreeNode:
    """XGBoost 树节点"""

    def __init__(self, feature=None, threshold=None, left=None, right=None, weight=None, samples=None):
        self.feature = feature
        self.threshold = threshold
        self.left = left
        self.right = right
        self.weight = weight
        self.samples = samples

    def is_leaf(self):
        return self.weight is not None


class XGBTree:
    """手写 XGBoost 决策树 - 二阶导数和增益公式"""

    def __init__(self, max_depth=5, min_child_weight=1, lambda_reg=1.0, gamma=0.0):
        self.max_depth = max_depth
        self.min_child_weight = min_child_weight
        self.lambda_reg = lambda_reg
        self.gamma = gamma
        self.tree = None

    def fit(self, X, g, h):
        """拟合树"""
        self.tree = self._build_tree(X, g, h, depth=0)
        return self

    def _build_tree(self, X, g, h, depth):
        n_samples = X.shape[0]
        G = np.sum(g)
        H = np.sum(h)

        if (depth >= self.max_depth or n_samples == 0 or H < 1e-8):
            weight = -G / (H + self.lambda_reg) if H > 0 else 0.0
            return XGBTreeNode(weight=weight, samples=n_samples)

        best_split = None
        best_gain = 0

        for feature in range(X.shape[1]):
            thresholds = np.unique(X[:, feature])
            for threshold in thresholds:
                left_mask = X[:, feature] <= threshold
                right_mask = ~left_mask

                n_left = left_mask.sum()
                n_right = right_mask.sum()

                if n_left < self.min_child_weight or n_right < self.min_child_weight:
                    continue

                G_left = np.sum(g[left_mask])
                H_left = np.sum(h[left_mask])
                G_right = np.sum(g[right_mask])
                H_right = np.sum(h[right_mask])

                gain = (G_left ** 2 / (H_left + self.lambda_reg) +
                        G_right ** 2 / (H_right + self.lambda_reg) -
                        G ** 2 / (H + self.lambda_reg)) / 2 - self.gamma

                if gain > best_gain:
                    best_gain = gain
                    best_split = (feature, threshold, left_mask, right_mask)

        if best_split is None:
            weight = -G / (H + self.lambda_reg) if H > 0 else 0.0
            return XGBTreeNode(weight=weight, samples=n_samples)

        feature, threshold, left_mask, right_mask = best_split
        left_tree = self._build_tree(X[left_mask], g[left_mask], h[left_mask], depth + 1)
        right_tree = self._build_tree(X[right_mask], g[right_mask], h[right_mask], depth + 1)

        return XGBTreeNode(feature=feature, threshold=threshold, left=left_tree, right=right_tree, samples=n_samples)

    def predict(self, X):
        """返回树的预测"""
        return np.array([self._traverse_tree(x, self.tree) for x in X])

    def _traverse_tree(self, x, node):
        """遍历树获取叶子权重"""
        if node.is_leaf():
            return node.weight

        if x[node.feature] <= node.threshold:
            return self._traverse_tree(x, node.left)
        else:
            return self._traverse_tree(x, node.right)


class XGBoost:
    """手写 XGBoost - 二阶梯度提升"""

    def __init__(self, n_estimators=10, learning_rate=0.1, max_depth=5, min_child_weight=1, lambda_reg=1.0, gamma=0.0):
        self.n_estimators = n_estimators
        self.learning_rate = learning_rate
        self.max_depth = max_depth
        self.min_child_weight = min_child_weight
        self.lambda_reg = lambda_reg
        self.gamma = gamma
        self.trees = []
        self.train_losses = []
        self.train_accs = []
        self.test_accs = []
        self.init_score = 0.0

    def fit(self, X, y, X_test=None, y_test=None):
        """训练 XGBoost"""
        n_samples = X.shape[0]

        # 初始化 logit
        p_init = np.mean(y)
        self.init_score = np.log(p_init / (1 - p_init + 1e-8) + 1e-8)

        f = np.full(n_samples, self.init_score, dtype=np.float32)

        if X_test is not None:
            f_test = np.full(len(y_test), self.init_score, dtype=np.float32)

        print(f"\n[XGBoost] 开始训练 {self.n_estimators} 轮...")
        print(f"[XGBoost] 初始 logit = {self.init_score:.4f}")

        for iteration in range(self.n_estimators):
            p = self._sigmoid(f)
            g = p - y
            h = p * (1 - p)
            h = np.clip(h, 1e-8, None)

            tree = XGBTree(max_depth=self.max_depth,
                           min_child_weight=self.min_child_weight,
                           lambda_reg=self.lambda_reg,
                           gamma=self.gamma)
            tree.fit(X, g, h)
            self.trees.append(tree)

            tree_pred = tree.predict(X)
            f = f + self.learning_rate * tree_pred

            p_new = self._sigmoid(f)
            p_clipped = np.clip(p_new, 1e-7, 1 - 1e-7)
            loss = -np.mean(y * np.log(p_clipped) + (1 - y) * np.log(1 - p_clipped))

            y_pred = (p_new > 0.5).astype(int)
            acc = np.mean(y_pred == y)

            self.train_losses.append(loss)
            self.train_accs.append(acc)

            if X_test is not None:
                tree_pred_test = tree.predict(X_test)
                f_test = f_test + self.learning_rate * tree_pred_test
                p_test = self._sigmoid(f_test)
                y_test_pred = (p_test > 0.5).astype(int)
                test_acc = np.mean(y_test_pred == y_test)
                self.test_accs.append(test_acc)

                print(
                    f"[XGBoost] Iter {iteration + 1}/{self.n_estimators}: Loss={loss:.4f}, Train Acc={acc:.4f}, Test Acc={test_acc:.4f}")
            else:
                print(f"[XGBoost] Iter {iteration + 1}/{self.n_estimators}: Loss={loss:.4f}, Train Acc={acc:.4f}")

        print("[XGBoost] 训练完成！")
        return self

    def _sigmoid(self, x):
        """Sigmoid 函数"""
        return 1.0 / (1.0 + np.exp(-np.clip(x, -500, 500)))

    def predict(self, X):
        """预测"""
        f = np.full(X.shape[0], self.init_score, dtype=np.float32)

        for tree in self.trees:
            tree_pred = tree.predict(X)
            f = f + self.learning_rate * tree_pred

        p = self._sigmoid(f)
        return (p > 0.5).astype(int)

    def predict_proba(self, X):
        """返回概率"""
        f = np.full(X.shape[0], self.init_score, dtype=np.float32)

        for tree in self.trees:
            tree_pred = tree.predict(X)
            f = f + self.learning_rate * tree_pred

        p = self._sigmoid(f)
        return np.column_stack([1 - p, p])


# ==================== 7. 基于 XGBoost 的 MLP 编码器 ====================

class XGBLeafEncoderMLP(nn.Module):
    """基于 XGBoost 叶子编码的 MLP"""

    def __init__(self, xgb_model: XGBoost, X_train: np.ndarray, hidden_dim: int = 32):
        super().__init__()
        self.xgb_model = xgb_model

        # 获取叶子编码维度
        leaf_encodings = self._get_leaf_encodings(X_train)
        self.leaf_encoding_dim = leaf_encodings.shape[1]

        self.mlp = nn.Sequential(
            nn.Linear(self.leaf_encoding_dim, hidden_dim),
            nn.BatchNorm1d(hidden_dim),
            nn.ReLU(),
            nn.Dropout(0.5),
            nn.Linear(hidden_dim, 2)
        )

        self.train_losses = []
        self.train_accs = []
        self.test_accs = []

    def _get_leaf_encodings(self, X: np.ndarray) -> np.ndarray:
        """从 XGBoost 模型获取叶子编码"""
        encodings = []
        for tree in self.xgb_model.trees:
            pred = tree.predict(X).astype(np.float32).reshape(-1, 1)
            encodings.append(pred)

        return np.hstack(encodings) if encodings else np.zeros((X.shape[0], 1))

    def forward(self, X_enc: torch.Tensor) -> torch.Tensor:
        return self.mlp(X_enc)

    def fit(self, X_train, y_train, X_test, y_test, lr=1e-3, num_epochs=20, weight_decay=1e-3):
        """训练 MLP"""
        X_train_enc = torch.FloatTensor(self._get_leaf_encodings(X_train))
        X_test_enc = torch.FloatTensor(self._get_leaf_encodings(X_test))
        y_train_t = torch.LongTensor(y_train)
        y_test_t = torch.LongTensor(y_test)

        optimizer = torch.optim.Adam(self.parameters(), lr=lr, weight_decay=weight_decay)
        criterion = nn.CrossEntropyLoss()

        n_samples = X_train_enc.shape[0]

        print(f"\n[XGB+MLP] 开始训练 {num_epochs} 个 Epoch...")
        for epoch in range(num_epochs):
            self.train()
            perm = torch.randperm(n_samples)
            epoch_loss = 0
            epoch_acc = 0
            n_batches = 0

            for i in range(0, n_samples, 64):
                idx = perm[i:i + 64]
                xb = X_train_enc[idx]
                yb = y_train_t[idx]

                logits = self.forward(xb)
                loss = criterion(logits, yb)

                optimizer.zero_grad()
                loss.backward()
                optimizer.step()

                epoch_loss += loss.item()
                with torch.no_grad():
                    acc = (logits.argmax(dim=1) == yb).float().mean().item()
                    epoch_acc += acc
                n_batches += 1

            self.eval()
            with torch.no_grad():
                train_logits = self.forward(X_train_enc)
                train_acc = (train_logits.argmax(dim=1) == y_train_t).float().mean().item()
                train_loss = epoch_loss / n_batches

                test_logits = self.forward(X_test_enc)
                test_acc = (test_logits.argmax(dim=1) == y_test_t).float().mean().item()

            self.train_losses.append(train_loss)
            self.train_accs.append(train_acc)
            self.test_accs.append(test_acc)

            if (epoch + 1) % 5 == 0 or epoch == 0:
                print(
                    f"[XGB+MLP] Epoch {epoch + 1}/{num_epochs}: Loss={train_loss:.4f}, Train Acc={train_acc:.4f}, Test Acc={test_acc:.4f}")

    def predict(self, X: np.ndarray) -> np.ndarray:
        self.eval()
        with torch.no_grad():
            X_enc = torch.FloatTensor(self._get_leaf_encodings(X))
            logits = self.forward(X_enc)
            preds = logits.argmax(dim=1).cpu().numpy()
        return preds

    def predict_proba(self, X: np.ndarray) -> np.ndarray:
        self.eval()
        with torch.no_grad():
            X_enc = torch.FloatTensor(self._get_leaf_encodings(X))
            logits = self.forward(X_enc)
            probs = torch.softmax(logits, dim=1).cpu().numpy()
        return probs


# ==================== 8. 手写 Naive Bayes ====================

class GaussianNB:
    """手写高斯朴素贝叶斯分类器"""

    def __init__(self):
        self.class_priors = {}
        self.means = {}
        self.vars = {}
        self.classes = None

    def fit(self, X, y):
        """训练"""
        self.classes = np.unique(y)

        for c in self.classes:
            X_c = X[y == c]
            self.class_priors[c] = len(X_c) / len(X)
            self.means[c] = np.mean(X_c, axis=0)
            self.vars[c] = np.var(X_c, axis=0)

        return self

    def _gaussian_density(self, x, mean, var):
        """高斯概率密度函数"""
        numerator = np.exp(-(x - mean) ** 2 / (2 * var + 1e-8))
        denominator = np.sqrt(2 * np.pi * var + 1e-8)
        return numerator / denominator

    def predict(self, X):
        """预测"""
        predictions = []

        for x in X:
            posteriors = {}

            for c in self.classes:
                prior = np.log(self.class_priors[c])
                likelihood = np.sum(np.log(self._gaussian_density(x, self.means[c], self.vars[c]) + 1e-8))
                posteriors[c] = prior + likelihood

            predictions.append(max(posteriors, key=posteriors.get))

        return np.array(predictions)

    def predict_proba(self, X):
        """返回概率"""
        proba = []

        for x in X:
            posteriors = {}

            for c in self.classes:
                prior = self.class_priors[c]
                likelihood = np.prod(self._gaussian_density(x, self.means[c], self.vars[c]) + 1e-8)
                posteriors[c] = prior * likelihood

            # 归一化
            total = sum(posteriors.values())
            normalized = {k: v / total for k, v in posteriors.items()}
            proba.append([normalized.get(0, 0), normalized.get(1, 0)])

        return np.array(proba)

    def score(self, X, y):
        """计算准确率"""
        predictions = self.predict(X)
        return accuracy_score(y, predictions)


class NaiveBayesWrapper:
    """Naive Bayes 包装器"""

    def __init__(self):
        self.model = GaussianNB()
        self.train_accs = []
        self.test_accs = []

    def fit(self, X_train, y_train, X_test, y_test):
        """训练"""
        print(f"\n[Naive Bayes] 开始训练...")
        self.model.fit(X_train, y_train)
        train_acc = self.model.score(X_train, y_train)
        test_acc = self.model.score(X_test, y_test)

        self.train_accs.append(train_acc)
        self.test_accs.append(test_acc)

        print(f"[Naive Bayes] 训练完成！Train Acc={train_acc:.4f}, Test Acc={test_acc:.4f}")

    def predict(self, X):
        return self.model.predict(X)

    def predict_proba(self, X):
        return self.model.predict_proba(X)


# ==================== 9. 辅助函数 ====================

def load_and_preprocess_data(file_path):
    df = pd.read_csv(file_path)
    df = feature_engineering(df)
    X = df.drop(['blueWins'], axis=1).values
    y = df['blueWins'].values

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    scaler = StandardScaler()
    X_train = scaler.fit_transform(X_train)
    X_test = scaler.transform(X_test)

    return X_train, X_test, y_train, y_test, df.columns.drop('blueWins')


def evaluate_model(model, X_test, y_test, model_name):
    y_pred = model.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    p, r, f1, _ = precision_recall_fscore_support(y_test, y_pred, average='binary')
    print(f"[{model_name}] Acc: {acc:.4f} | Precision: {p:.4f} | Recall: {r:.4f} | F1: {f1:.4f}")
    return {'name': model_name, 'accuracy': acc, 'precision': p, 'recall': r, 'f1': f1, 'predictions': y_pred}


def visualize_results(results, X_test, y_test, models_dict):
    """生成混淆矩阵和 ROC 曲线"""
    for result in results:
        name = result['name']
        cm = confusion_matrix(y_test, result['predictions'])

        plt.figure(figsize=(4, 3))
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
        plt.title(f'{name} Confusion Matrix')
        plt.tight_layout()
        plt.savefig(f'confusion_{name}.png', dpi=300, bbox_inches='tight')
        plt.close()

    plt.figure(figsize=(10, 6))
    plotted = False

    for r in results:
        name = r['name']
        if name in models_dict and hasattr(models_dict[name], 'predict_proba'):
            try:
                probs = models_dict[name].predict_proba(X_test)
                if probs.ndim == 2 and probs.shape[1] == 2:
                    y_score = probs[:, 1]
                elif probs.ndim == 1:
                    y_score = probs
                else:
                    continue

                fpr, tpr, _ = roc_curve(y_test, y_score)
                roc_auc = auc(fpr, tpr)
                plt.plot(fpr, tpr, label=f'{name} (AUC={roc_auc:.3f})')
                plotted = True
            except Exception as e:
                pass

    if plotted:
        plt.plot([0, 1], [0, 1], 'k--')
        plt.xlabel('False Positive Rate')
        plt.ylabel('True Positive Rate')
        plt.title('ROC Curve Comparison')
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        plt.savefig('improved_roc.png', dpi=300, bbox_inches='tight')
        plt.close()

    print("\n可视化结果已保存：confusion_*.png 和 improved_roc.png")


def plot_model_comparison(results):
    """绘制所有模型的 Acc、Precision、Recall、F1 对比柱状图"""
    names = [r['name'] for r in results]
    accs = [r['accuracy'] for r in results]
    precisions = [r['precision'] for r in results]
    recalls = [r['recall'] for r in results]
    f1s = [r['f1'] for r in results]

    x = np.arange(len(names))
    width = 0.2

    fig, ax = plt.subplots(figsize=(14, 6))

    bars1 = ax.bar(x - 1.5 * width, accs, width, label='Accuracy', color='#1f77b4')
    bars2 = ax.bar(x - 0.5 * width, precisions, width, label='Precision', color='#ff7f0e')
    bars3 = ax.bar(x + 0.5 * width, recalls, width, label='Recall', color='#2ca02c')
    bars4 = ax.bar(x + 1.5 * width, f1s, width, label='F1-Score', color='#d62728')

    ax.set_ylabel('Score', fontsize=12)
    ax.set_title('模型性能对比 (Accuracy, Precision, Recall, F1)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(names, rotation=45, ha='right')
    ax.legend()
    ax.set_ylim([0, 1.05])
    ax.grid(axis='y', alpha=0.3)

    # 添加数值标签
    for bars in [bars1, bars2, bars3, bars4]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width() / 2., height,
                    f'{height:.3f}', ha='center', va='bottom', fontsize=8)

    plt.tight_layout()
    plt.savefig('model_comparison.png', dpi=300, bbox_inches='tight')
    plt.close()

    print("模型对比柱状图已保存：model_comparison.png")


# ==================== 10. 主流程 ====================

def main(data_path):
    print("加载数据并进行高级特征工程...")
    X_train, X_test, y_train, y_test, feats = load_and_preprocess_data(data_path)

    results = []
    models_dict = {}

    # --- 1. Softmax 回归 ---
    print("\n" + "=" * 60)
    print("训练 Softmax 回归...")
    print("=" * 60)
    softmax = SoftmaxRegression(input_dim=X_train.shape[1], num_classes=2, learning_rate=0.005, num_epochs=20,
                                batch_size=256, l2_lambda=2e-3)
    softmax.fit(X_train, y_train, X_test, y_test)
    models_dict['Softmax'] = softmax
    results.append(evaluate_model(softmax, X_test, y_test, 'Softmax'))

    # --- 2. Logistic Regression ---
    print("\n" + "=" * 60)
    print("训练 Logistic Regression...")
    print("=" * 60)
    lr = LogisticRegressionWrapper(max_iter=1000, learning_rate=0.01)
    lr.fit(X_train, y_train, X_test, y_test)
    models_dict['LogisticRegression'] = lr
    results.append(evaluate_model(lr, X_test, y_test, 'LogisticRegression'))

    # --- 3. Decision Tree ---
    print("\n" + "=" * 60)
    print("训练 Decision Tree...")
    print("=" * 60)
    dt = DecisionTreeWrapper(max_depth=10, min_samples_split=10, min_samples_leaf=5)
    dt.fit(X_train, y_train, X_test, y_test)
    models_dict['DecisionTree'] = dt
    results.append(evaluate_model(dt, X_test, y_test, 'DecisionTree'))

    # --- 4. Random Forest ---
    print("\n" + "=" * 60)
    print("训练 Random Forest...")
    print("=" * 60)
    rf = RandomForestWrapper(n_estimators=50, max_depth=8, min_samples_split=10)
    rf.fit(X_train, y_train, X_test, y_test)
    models_dict['RandomForest'] = rf
    results.append(evaluate_model(rf, X_test, y_test, 'RandomForest'))

    # --- 5. 手写 XGBoost ---
    print("\n" + "=" * 60)
    print("训练 手写 XGBoost (10轮)...")
    print("=" * 60)
    xgb = XGBoost(n_estimators=10, learning_rate=0.1, max_depth=5, min_child_weight=1, lambda_reg=1.0, gamma=0.0)
    xgb.fit(X_train, y_train, X_test, y_test)
    models_dict['XGBoost'] = xgb
    results.append(evaluate_model(xgb, X_test, y_test, 'XGBoost'))

    # --- 6. XGB+MLP ---
    print("\n" + "=" * 60)
    print("训练 XGB+MLP (基于手写 XGBoost 的 MLP)...")
    print("=" * 60)
    xgb_mlp = XGBLeafEncoderMLP(xgb, X_train, hidden_dim=32)
    xgb_mlp.fit(X_train, y_train, X_test, y_test, lr=0.001, num_epochs=20, weight_decay=1e-3)
    models_dict['XGB+MLP'] = xgb_mlp
    results.append(evaluate_model(xgb_mlp, X_test, y_test, 'XGB+MLP'))

    # --- 7. Naive Bayes ---
    print("\n" + "=" * 60)
    print("训练 Naive Bayes...")
    print("=" * 60)
    nb = NaiveBayesWrapper()
    nb.fit(X_train, y_train, X_test, y_test)
    models_dict['NaiveBayes'] = nb
    results.append(evaluate_model(nb, X_test, y_test, 'NaiveBayes'))

    # 可视化
    print("\n生成可视化图表...")
    visualize_results(results, X_test, y_test, models_dict)

    # 绘制模型对比柱状图
    print("\n生成模型对比柱状图...")
    plot_model_comparison(results)

    # 总结
    print("\n" + "=" * 60)
    print("模型对比总结")
    print("=" * 60)
    sorted_results = sorted(results, key=lambda x: x['accuracy'], reverse=True)
    for i, r in enumerate(sorted_results, 1):
        print(
            f"{i}. {r['name']}: Acc={r['accuracy']:.4f}, Precision={r['precision']:.4f}, Recall={r['recall']:.4f}, F1={r['f1']:.4f}")


if __name__ == '__main__':
    path = './high_diamond_ranked_10min.csv/high_diamond_ranked_10min.csv'
    if not os.path.exists(path):
        path = 'high_diamond_ranked_10min.csv'
    if os.path.exists(path):
        main(path)
    else:
        print(f"Error: 找不到数据文件 {path}，请检查路径。")
