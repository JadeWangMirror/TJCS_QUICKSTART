import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.cluster import KMeans, DBSCAN, AgglomerativeClustering
from sklearn.metrics import silhouette_score, davies_bouldin_score
from kneed import KneeLocator
from sklearn.decomposition import PCA
from sklearn.neighbors import NearestNeighbors
from scipy.cluster.hierarchy import dendrogram, linkage
from matplotlib.font_manager import FontProperties

# --- 解决 Matplotlib 中文乱码问题 ---
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'Heiti TC', 'Arial Unicode MS'] 
plt.rcParams['axes.unicode_minus'] = False 
# ------------------------------------

# 设置 Matplotlib 和 Seaborn 样式
plt.style.use('ggplot')

# --- 辅助函数：保存图片 ---
def save_and_show_plot(fig_title):
    """保存当前图形并显示，确保中文文件名兼容"""
    safe_filename = fig_title.replace(' ', '_').replace('(', '_').replace(')', '').replace('/', '_vs_')
    plt.savefig(f'./{safe_filename}.png', bbox_inches='tight')
    print(f"图表已保存为: {safe_filename}.png")
    plt.show()

# --- 新增函数：绘制簇特征柱状图 (已优化布局) ---
def plot_cluster_features(df, cluster_col, original_features, n_clusters):
    """绘制每个聚类簇中所有原始特征的平均值柱状图，并优化布局"""
    
    # 计算每个簇的特征平均值
    cluster_profile = df.groupby(cluster_col)[original_features].mean()
    
    # 使用所有原始特征
    plot_features = original_features
    
    # 绘制
    rows = int(np.ceil(len(plot_features) / 3)) # 调整为每行显示 3 个图
    
    # 调整画布大小，宽度设为 15，高度与行数相关
    plt.figure(figsize=(15, 5 * rows)) 
    
    # 如果是 DBSCAN，将噪声点（-1）排除在颜色分配之外，但保留在图上
    if cluster_col == 'DBSCAN_Cluster':
        # 考虑到 DBSCAN 的簇数量可能较少，使用 tab10
        palette_colors = sns.color_palette('tab10', n_clusters + 1) 
        cluster_labels = sorted(df[cluster_col].unique())
        # 将 -1（噪声）设置为灰色
        cluster_colors = {label: ('gray' if label == -1 else palette_colors[i % (len(palette_colors)-1)]) 
                          for i, label in enumerate(cluster_labels)}
    else:
        # K-Means, Agglomerative 使用标准的 K 种颜色
        palette_colors = sns.color_palette('viridis', n_clusters)
        cluster_labels = sorted(df[cluster_col].unique())
        cluster_colors = {label: palette_colors[label % len(palette_colors)] for label in cluster_labels}

    
    for i, feature in enumerate(plot_features):
        plt.subplot(rows, 3, i + 1)
        
        # 针对每个簇绘制柱状图
        bar_colors = [cluster_colors[c] for c in cluster_profile.index]
        cluster_profile[feature].plot(kind='bar', color=bar_colors)
        
        plt.title(f'簇平均值: {feature}', fontsize=12)
        plt.ylabel('平均值')
        plt.xlabel(f'{cluster_col}')
        plt.xticks(rotation=0)
        
    # 核心修正：增加子图之间的填充
    plt.tight_layout(w_pad=2.0, h_pad=3.0) 
    save_and_show_plot(f'{cluster_col}_All_Feature_Profiles')


# --- 1. Data Prepare (数据加载) ---
FILE_PATH = './segmentation data.csv' 
try:
    df = pd.read_csv(FILE_PATH)
    if len(df) < 100:
        print("警告：数据行数较少，聚类结果可能不稳定。")
except FileNotFoundError:
    print(f"错误：未找到文件 {FILE_PATH}。请检查文件名和路径。")
    exit()

print("--- 1. Data Prepare (数据预览与信息) ---")
df_original = df.copy() 

if 'ID' in df.columns:
    df = df.drop('ID', axis=1)
elif 'CustomerID' in df.columns:
    df = df.drop('CustomerID', axis=1)
else:
    print("未发现明显的ID列，继续使用所有列。")

# --- 2. Data Preprocess (数据预处理) ---
numerical_features = df.select_dtypes(include=np.number).columns.tolist()
categorical_features = df.select_dtypes(include='object').columns.tolist()

for col in numerical_features:
    df[col] = df[col].fillna(df[col].median())

for col in categorical_features:
    df[col] = df[col].fillna(df[col].mode()[0])

preprocessor = ColumnTransformer(
    transformers=[
        ('num', StandardScaler(), numerical_features),
        ('cat', OneHotEncoder(handle_unknown='ignore', sparse_output=False), categorical_features)
    ])

X_processed = preprocessor.fit_transform(df)

if categorical_features:
    feature_names = numerical_features + list(preprocessor.named_transformers_['cat'].get_feature_names_out(categorical_features))
else:
    feature_names = numerical_features
X_processed_df = pd.DataFrame(X_processed, columns=feature_names)

print("\n--- 2. Data Preprocess (处理后数据形状) ---")
print(f"原始特征数: {len(df.columns)}, 处理后特征数: {X_processed.shape[1]}")


# ----------------------------------------------------
# 实验一：K-均值聚类 (K-Means)
# ----------------------------------------------------

print("\n\n--- 3. K-Means: Model construct (选择 K 值 - 肘部法则) ---")

sse = {}
K_range = range(2, 11)

for k in K_range:
    kmeans = KMeans(n_clusters=k, random_state=42, n_init='auto', max_iter=300)
    kmeans.fit(X_processed)
    sse[k] = kmeans.inertia_
    
plt.figure(figsize=(8, 5))
plt.plot(K_range, list(sse.values()), marker='o', linestyle='-')
plt.title('肘部法则 (K vs. SSE)')
plt.xlabel('簇的数量 (K)')
plt.ylabel('SSE (Inertia)')
plt.xticks(K_range)

kl = KneeLocator(K_range, list(sse.values()), curve='convex', direction='decreasing')
optimal_k_elbow = kl.elbow if kl.elbow is not None else 4
# 强制设定 K=6
optimal_k_kmeans = 6 
plt.axvline(x=optimal_k_kmeans, color='r', linestyle='--', label=f'手动设定 K={optimal_k_kmeans}')
plt.legend()
plt.tight_layout()
save_and_show_plot('KMeans_K_Selection_Elbow_Only')


print(f"\nK-Means 选定的最佳 K 值为: {optimal_k_kmeans} (手动设定)")


# --- 4 & 5. K-Means: Train & Test & Plot ---
kmeans_final = KMeans(n_clusters=optimal_k_kmeans, random_state=42, n_init='auto', max_iter=300)
df['KMeans_Cluster'] = kmeans_final.fit_predict(X_processed)

k_means_silhouette = silhouette_score(X_processed, df['KMeans_Cluster'])
k_means_dbi = davies_bouldin_score(X_processed, df['KMeans_Cluster'])

print("\n--- K-Means 聚类性能评估 ---")
print(f"轮廓系数 (Silhouette Score): {k_means_silhouette:.4f}")
print(f"戴维斯-布尔丁指数 (DBI): {k_means_dbi:.4f}")

# 降维：使用 PCA
pca = PCA(n_components=2, random_state=42)
X_pca = pca.fit_transform(X_processed)

df['PCA1'] = X_pca[:, 0]
df['PCA2'] = X_pca[:, 1]

plt.figure(figsize=(10, 8))
sns.scatterplot(x='PCA1', y='PCA2', hue='KMeans_Cluster', data=df, 
                palette='viridis', s=50, alpha=0.7, legend='full')

centers_pca = pca.transform(kmeans_final.cluster_centers_)
plt.scatter(centers_pca[:, 0], centers_pca[:, 1], marker='X', s=300, 
            c='red', label='聚类中心', edgecolors='black')

plt.title(f'K-Means 聚类结果可视化 (K={optimal_k_kmeans}) - PCA 降维')
plt.xlabel(f'主成分 1 (解释方差: {pca.explained_variance_ratio_[0]*100:.2f}%)')
plt.ylabel(f'主成分 2 (解释方差: {pca.explained_variance_ratio_[1]*100:.2f}%)')
plt.legend(title='簇标签')
plt.grid(True)
save_and_show_plot('KMeans_Result_PCA')


# --- 新增功能：K-Means 簇特征分析图 ---
original_features_list = df_original.drop(columns=['ID', 'CustomerID'], errors='ignore').columns.tolist()
plot_cluster_features(df, 'KMeans_Cluster', original_features_list, optimal_k_kmeans)


# ----------------------------------------------------
# 实验二：DBSCAN 聚类 (基于密度) 
# ----------------------------------------------------

print("\n\n--- 3. DBSCAN: Model construct (超参数选择 - Eps & min_samples) ---")
# min_samples = 2 * X_processed.shape[1] 
min_samples = 5

print(f"设置 min_samples = {min_samples}")

neigh = NearestNeighbors(n_neighbors=min_samples)
distances, indices = neigh.fit(X_processed).kneighbors(X_processed)
distances = np.sort(distances[:, min_samples-1], axis=0) 

plt.figure(figsize=(10, 6))
plt.plot(distances)
plt.title(f'K-距离图 (k={min_samples}) - 确定 Eps')
plt.xlabel('数据点索引 (排序后)')
plt.ylabel(f'到第 {min_samples} 个邻居的距离')
plt.grid(True)
save_and_show_plot('DBSCAN_K_Distance_Plot')

optimal_eps = 1.65
print(f"根据 K-距离图，手动确定最佳 Eps 并修改代码。当前使用的值是: {optimal_eps}")


# --- 4 & 5. DBSCAN: Train & Test & Plot ---
dbscan_final = DBSCAN(eps=optimal_eps, min_samples=min_samples)
df['DBSCAN_Cluster'] = dbscan_final.fit_predict(X_processed)

dbscan_silhouette = None
dbscan_dbi = None
valid_indices = df['DBSCAN_Cluster'] != -1
# 强制设定期望的有效簇数量为 6，用于评估。注意：DBSCAN 不保证产生 6 个簇
expected_k_dbscan = 6 
num_clusters_dbscan = len(np.unique(df['DBSCAN_Cluster'][valid_indices]))


    
if num_clusters_dbscan > 1 and len(df[valid_indices]) > 1:
    dbscan_silhouette = silhouette_score(X_processed[valid_indices], df['DBSCAN_Cluster'][valid_indices])
    dbscan_dbi = davies_bouldin_score(X_processed[valid_indices], df['DBSCAN_Cluster'][valid_indices])
    
    print(f"发现的有效簇数量: {num_clusters_dbscan}")
    print(f"轮廓系数 (Silhouette Score): {dbscan_silhouette:.4f}")
    print(f"戴维斯-布尔丁指数 (DBI): {dbscan_dbi:.4f}")
    print(f"噪声点数量 (-1 簇): {len(df[df['DBSCAN_Cluster'] == -1])}")
else:
    print("DBSCAN 未发现有效簇或所有点均为噪声/单簇。无法计算轮廓系数/DBI。")
    print(f"发现的簇数量: {num_clusters_dbscan}")


plt.figure(figsize=(10, 8))
sns.scatterplot(x='PCA1', y='PCA2', hue='DBSCAN_Cluster', data=df, 
                palette='tab10', s=50, alpha=0.7, legend='full')

plt.title(f'DBSCAN 聚类结果可视化 (Eps={optimal_eps}) - PCA 降维')
plt.xlabel(f'主成分 1')
plt.ylabel(f'主成分 2')
plt.legend(title='簇标签')
plt.grid(True)
save_and_show_plot('DBSCAN_Result_PCA')


# --- 新增功能：DBSCAN 簇特征分析图 ---
# 仅对有效簇（非噪声点）进行特征分析
df_dbscan_valid = df[df['DBSCAN_Cluster'] != -1].copy()
if num_clusters_dbscan > 1:
     plot_cluster_features(df, 'DBSCAN_Cluster', original_features_list, num_clusters_dbscan)
else:
     print("\nDBSCAN 结果中有效簇不足，跳过特征柱状图绘制。")


# ----------------------------------------------------
# 实验三：层次聚类 (Agglomerative Clustering)
# ----------------------------------------------------

print("\n\n--- 3. Agglomerative: Model construct (选择最佳 K 值 - 树状图) ---")

linked = linkage(X_processed, method='ward')

plt.figure(figsize=(15, 7))
dendrogram(
    linked,
    orientation='top',
    truncate_mode='lastp',  
    p=30, 
    show_leaf_counts=True,
    distance_sort='descending'
)
plt.title('层次聚类树状图 (Dendrogram)')
plt.xlabel('样本点索引或聚类数量')
plt.ylabel('欧氏距离 (Euclidean Distance)')

# ❗ 修正点：将 K 设为 6
optimal_k_agglo = 6 
print(f"\n根据树状图，请手动确定最佳 K 并修改代码。当前使用的值是: {optimal_k_agglo}")

# 绘制一条水平线来帮助确定 K 值
plt.axhline(y=10, color='r', linestyle='--', label=f'截断线 (K={optimal_k_agglo})') 
plt.legend()
save_and_show_plot('Agglomerative_Dendrogram')


# --- 4 & 5. Agglomerative: Train & Test & Plot ---
agglo_final = AgglomerativeClustering(n_clusters=optimal_k_agglo, linkage='ward')
df['Agglo_Cluster'] = agglo_final.fit_predict(X_processed)

agglo_silhouette = silhouette_score(X_processed, df['Agglo_Cluster'])
agglo_dbi = davies_bouldin_score(X_processed, df['Agglo_Cluster'])

print("\n--- Agglomerative 聚类性能评估 ---")
print(f"轮廓系数 (Silhouette Score): {agglo_silhouette:.4f}")
print(f"戴维斯-布尔丁指数 (DBI): {agglo_dbi:.4f}")


plt.figure(figsize=(10, 8))
sns.scatterplot(x='PCA1', y='PCA2', hue='Agglo_Cluster', data=df, 
                palette='tab20', s=50, alpha=0.7, legend='full')

plt.title(f'Agglomerative 聚类结果可视化 (K={optimal_k_agglo}) - PCA 降维')
plt.xlabel(f'主成分 1')
plt.ylabel(f'主成分 2')
plt.legend(title='簇标签')
plt.grid(True)
save_and_show_plot('Agglomerative_Result_PCA')


# --- 新增功能：Agglomerative 簇特征分析图 ---
plot_cluster_features(df, 'Agglo_Cluster', original_features_list, optimal_k_agglo)


# --- 6. Optimize & Review (总结对比) ---

print("\n\n--- 6. Optimize & Review (聚类方法对比总结) ---")
print("| 方法 | 关键参数 | 轮廓系数 | DBI |")
print("| :--- | :--- | :--- | :--- |")
print(f"| K-Means (划分) | K={optimal_k_kmeans} | {k_means_silhouette:.4f} | {k_means_dbi:.4f} |")
print(f"| DBSCAN (密度) | Eps={optimal_eps} | {'-' if dbscan_silhouette is None else f'{dbscan_silhouette:.4f}'} | {'-' if dbscan_dbi is None else f'{dbscan_dbi:.4f}'} |")
print(f"| Agglo (层次) | K={optimal_k_agglo} | {agglo_silhouette:.4f} | {agglo_dbi:.4f} |")

# 详细分析 K-Means 簇特征 (使用原始非标准化数据)
print("\n--- K-Means 簇特征描述 (原始数据均值) ---")
cluster_profile = df.groupby('KMeans_Cluster')[original_features_list].mean()
print(cluster_profile)

df_dbscan_valid = df[df['DBSCAN_Cluster'] != -1].copy()
if num_clusters_dbscan > 1:
    plot_cluster_features(df, 'DBSCAN_Cluster', original_features_list, num_clusters_dbscan)
    
    # --- 新增：DBSCAN 簇特征描述 (原始数据均值) ---
    print("\n--- DBSCAN 簇特征描述 (原始数据均值) ---")
    # 聚类描述表只应包含有效的簇 (-1 除外)
    cluster_profile_dbscan = df[df['DBSCAN_Cluster'] != -1].groupby('DBSCAN_Cluster')[original_features_list].mean()
    print(cluster_profile_dbscan)
    
else:
    print("\nDBSCAN 结果中有效簇不足，跳过特征柱状图绘制和表格输出。")

print("\n--- Agglomerative 簇特征描述 (原始数据均值) ---")
cluster_profile_agglo = df.groupby('Agglo_Cluster')[original_features_list].mean()
print(cluster_profile_agglo)

