import sys
import heapq
from collections import defaultdict, deque
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QTextEdit, QPushButton, QLabel, QLineEdit, QTabWidget, QTableWidget,
    QTableWidgetItem, QMessageBox, QSplitter, QGroupBox, QScrollArea
)
from PySide6.QtCore import Qt, QTimer
import networkx as nx
import matplotlib.pyplot as plt
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas

class GraphCanvas(FigureCanvas):
    def __init__(self, parent=None):
        self.fig, self.ax = plt.subplots(figsize=(8, 6))
        super().__init__(self.fig)
        self.setParent(parent)
        self.ax.set_title("Graph Visualization")
        self.fixed_positions = None
        self.draw()

    def draw_graph(self, G, highlight_edges=[], highlight_nodes=[], title="Graph"):
        self.ax.clear()
        
        # Use fixed layout for consistent positioning
        if self.fixed_positions is None or len(self.fixed_positions) != len(G.nodes()):
            self.fixed_positions = nx.spring_layout(G, seed=42)  # Fixed seed for consistent layout
        
        # Draw all nodes and edges
        nx.draw_networkx_nodes(G, self.fixed_positions, ax=self.ax, node_color='lightblue', node_size=800)
        nx.draw_networkx_edges(G, self.fixed_positions, ax=self.ax, edge_color='gray', width=2)
        nx.draw_networkx_labels(G, self.fixed_positions, ax=self.ax, font_size=12, font_weight='bold')
        
        # Draw edge labels (weights)
        edge_labels = nx.get_edge_attributes(G, 'weight')
        nx.draw_networkx_edge_labels(G, self.fixed_positions, edge_labels=edge_labels, ax=self.ax, font_size=10)
        
        # Highlight specific edges
        if highlight_edges:
            nx.draw_networkx_edges(G, self.fixed_positions, edgelist=highlight_edges, 
                                  edge_color='red', width=3, ax=self.ax)
        
        # Highlight specific nodes
        if highlight_nodes:
            nx.draw_networkx_nodes(G, self.fixed_positions, nodelist=highlight_nodes, 
                                  node_color='orange', node_size=800, ax=self.ax)
        
        self.ax.set_title(title, fontsize=14, fontweight='bold')
        self.ax.axis('off')
        self.draw()

class GraphApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Graph Algorithms Visualizer")
        self.setGeometry(100, 100, 1400, 900)
        self.graph = nx.Graph()
        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)
        self.layout = QHBoxLayout(self.central_widget)
        
        self.canvas = GraphCanvas(self)
        self.text_output = QTextEdit()
        self.text_output.setReadOnly(True)
        
        self.tab_widget = QTabWidget()
        self.setup_ui()
        
        self.layout.addWidget(self.canvas, 60)
        self.layout.addWidget(self.tab_widget, 40)
        
        # For step-by-step visualization
        self.timer = QTimer()
        self.timer.timeout.connect(self.next_step)
        self.current_algorithm = None
        self.algorithm_steps = []
        self.current_step = 0
        
        # 存储最终距离矩阵
        self.final_distance_matrix = None
        
    def setup_ui(self):
        # Input Tab
        input_tab = QWidget()
        input_layout = QVBoxLayout(input_tab)
        
        # Example input
        example_label = QLabel("Example: A-B-5, B-C-3, C-D-7, D-A-2, A-C-6, B-D-4")
        input_layout.addWidget(example_label)
        
        self.edge_input = QLineEdit()
        self.edge_input.setPlaceholderText("Enter edges (e.g., A-B-2, B-C-3)")
        input_layout.addWidget(QLabel("Edges (format: node1-node2-weight):"))
        input_layout.addWidget(self.edge_input)
        
        self.build_btn = QPushButton("Build Graph and Show Adjacency List")
        self.build_btn.clicked.connect(self.build_graph)
        input_layout.addWidget(self.build_btn)
        
        # Prim's algorithm start node input
        prim_start_layout = QHBoxLayout()
        prim_start_layout.addWidget(QLabel("Prim's Start Node:"))
        self.prim_start_input = QLineEdit()
        self.prim_start_input.setPlaceholderText("Enter start node for Prim's algorithm")
        prim_start_layout.addWidget(self.prim_start_input)
        input_layout.addLayout(prim_start_layout)
        
        # Algorithm buttons
        prim_group = QGroupBox("Minimum Spanning Tree")
        prim_layout = QVBoxLayout(prim_group)
        self.prim_btn = QPushButton("Run Prim's Algorithm")
        self.prim_btn.clicked.connect(self.run_prim)
        prim_layout.addWidget(self.prim_btn)
        
        self.kruskal_btn = QPushButton("Run Kruskal's Algorithm")
        self.kruskal_btn.clicked.connect(self.run_kruskal)
        prim_layout.addWidget(self.kruskal_btn)
        input_layout.addWidget(prim_group)
        
        # Shortest path buttons
        path_group = QGroupBox("Shortest Path")
        path_layout = QVBoxLayout(path_group)
        self.dijkstra_btn = QPushButton("Run Dijkstra (All Pairs)")
        self.dijkstra_btn.clicked.connect(self.run_all_pairs_dijkstra)
        path_layout.addWidget(self.dijkstra_btn)
        
        input_layout.addWidget(path_group)
        
        # 添加距离矩阵表格
        table_group = QGroupBox("Final Distance Matrix")
        table_layout = QVBoxLayout(table_group)
        self.distance_table = QTableWidget()
        self.distance_table.setMaximumHeight(180)
        self.distance_table.setMaximumWidth(400)
        self.distance_table.verticalHeader().setVisible(False)
        self.distance_table.horizontalHeader().setVisible(False)
        self.distance_table.setShowGrid(True)
        table_layout.addWidget(self.distance_table)
        input_layout.addWidget(table_group)
        
        input_layout.addStretch()
        self.tab_widget.addTab(input_tab, "Input")
        
        # Output Tab
        output_tab = QWidget()
        output_layout = QVBoxLayout(output_tab)
        output_layout.addWidget(self.text_output)
        self.tab_widget.addTab(output_tab, "Output")
        
    def build_graph(self):
        try:
            self.graph.clear()
            edges_text = self.edge_input.text().strip()
            if not edges_text:
                QMessageBox.warning(self, "Input Error", "Please enter edges.")
                return
                
            for edge in edges_text.split(','):
                parts = edge.strip().split('-')
                if len(parts) < 2:
                    continue
                u, v = parts[0].strip(), parts[1].strip()
                w = int(parts[2]) if len(parts) > 2 else 1
                self.graph.add_edge(u, v, weight=w)
                
            self.canvas.draw_graph(self.graph, title="Graph Visualization")
            self.show_adjacency_list()
            self.text_output.append("Graph built successfully.")
            
            # 清空距离矩阵表格
            self.distance_table.clear()
            self.distance_table.setRowCount(0)
            self.distance_table.setColumnCount(0)
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Error building graph: {e}")
            
    def show_adjacency_list(self):
        self.text_output.append("\n=== Adjacency List ===")
        for node in sorted(self.graph.nodes()):
            neighbors = []
            for neighbor in self.graph.neighbors(node):
                weight = self.graph[node][neighbor]['weight']
                neighbors.append(f"{neighbor}({weight})")
            self.text_output.append(f"{node}: {', '.join(neighbors)}")
            
    def next_step(self):
        if not self.algorithm_steps or self.current_step >= len(self.algorithm_steps):
            self.timer.stop()
            return
            
        step_func = self.algorithm_steps[self.current_step]
        step_func()
        self.current_step += 1
        
        if self.current_step >= len(self.algorithm_steps):
            self.timer.stop()
            
    def run_prim(self):
        if not self.graph.nodes:
            QMessageBox.warning(self, "Error", "Graph is empty.")
            return

        # 获取起始节点
        start_node = self.prim_start_input.text().strip()
        if not start_node:
            # 如果没有指定起始节点，使用第一个节点
            start_node = next(iter(self.graph.nodes))
        elif start_node not in self.graph.nodes:
            QMessageBox.warning(self, "Error", f"Start node '{start_node}' not found in graph.")
            return

        self.current_algorithm = "prim"
        self.algorithm_steps = []
        self.current_step = 0

        mst_edges = []
        visited = set()
        visited.add(start_node)

        self.text_output.append("\n=== Prim's Algorithm ===")
        self.text_output.append(f"Starting from node: {start_node}")

        edges = []  # (weight, u, v)
        for neighbor in self.graph.neighbors(start_node):
            weight = self.graph[start_node][neighbor]['weight']
            heapq.heappush(edges, (weight, start_node, neighbor))

        # 存储每一步的状态
        step_states = []
        step_count = 1

        while edges and len(visited) < len(self.graph.nodes):
            # 找到最小权重的边
            while edges:
                weight, u, v = heapq.heappop(edges)
                if v not in visited:
                    break
            else:
                break

            visited.add(v)
            mst_edges.append((u, v))

            # 记录此步状态
            step_states.append({
                'step': step_count,
                'add_edge': (u, v),
                'weight': weight,
                'visited': visited.copy(),
                'mst_edges': mst_edges.copy(),
                'msg': f"Add edge {u}-{v} (weight: {weight})"
            })

            # 添加新边
            for neighbor in self.graph.neighbors(v):
                if neighbor not in visited:
                    w = self.graph[v][neighbor]['weight']
                    heapq.heappush(edges, (w, v, neighbor))

            step_count += 1

        # 构建步骤函数
        for state in step_states:
            def make_step(s):
                def step():
                    self.text_output.append(f"Step {s['step']}: {s['msg']}")
                    self.text_output.append(f"  Visited nodes: {sorted(s['visited'])}")
                    self.canvas.draw_graph(
                        self.graph,
                        highlight_edges=s['mst_edges'],
                        highlight_nodes=s['visited'],
                        title=f"Prim's Algorithm - Step {s['step']}"
                    )
                return step
            self.algorithm_steps.append(make_step(state))

        # 最终步骤
        def final_step():
            total_weight = sum(self.graph[u][v]['weight'] for u, v in mst_edges)
            self.text_output.append(f"\nPrim's MST completed!")
            self.text_output.append(f"Total weight: {total_weight}")
            self.text_output.append(f"MST edges: {sorted(mst_edges)}")
            self.canvas.draw_graph(
                self.graph,
                highlight_edges=mst_edges,
                title="Prim's MST - Completed"
            )

        self.algorithm_steps.append(final_step)
        self.timer.start(1000)
        
    def run_kruskal(self):
        if not self.graph.nodes:
            QMessageBox.warning(self, "Error", "Graph is empty.")
            return

        self.current_algorithm = "kruskal"
        self.algorithm_steps = []
        self.current_step = 0

        parent = {}
        rank = {}

        def make_set(node):
            parent[node] = node
            rank[node] = 0

        def find(node):
            if parent[node] != node:
                parent[node] = find(parent[node])
            return parent[node]

        def union(node1, node2):
            r1, r2 = find(node1), find(node2)
            if r1 == r2:
                return False
            if rank[r1] < rank[r2]:
                parent[r1] = r2
            else:
                parent[r2] = r1
                if rank[r1] == rank[r2]:
                    rank[r1] += 1
            return True

        for node in self.graph.nodes:
            make_set(node)

        edges = sorted([(u, v, self.graph[u][v]['weight']) for u, v in self.graph.edges], key=lambda x: x[2])

        self.text_output.append("\n=== Kruskal's Algorithm ===")
        self.text_output.append("Edges sorted by weight: " +
                            ", ".join([f"{u}-{v}({w})" for u, v, w in edges]))

        mst_edges = []
        step_states = []
        step_count = 1

        for u, v, weight in edges:
            if find(u) != find(v):
                union(u, v)
                mst_edges.append((u, v))
                step_states.append({
                    'step': step_count,
                    'add_edge': (u, v),
                    'weight': weight,
                    'mst_edges': mst_edges.copy(),
                    'msg': f"Add edge {u}-{v} (weight: {weight})"
                })
                step_count += 1

        for state in step_states:
            def make_step(s):
                def step():
                    self.text_output.append(f"Step {s['step']}: {s['msg']}")
                    self.text_output.append(f"  Current MST edges: {sorted(s['mst_edges'])}")
                    self.canvas.draw_graph(
                        self.graph,
                        highlight_edges=s['mst_edges'],
                        title=f"Kruskal's Algorithm - Step {s['step']}"
                    )
                return step
            self.algorithm_steps.append(make_step(state))

        def final_step():
            total_weight = sum(self.graph[u][v]['weight'] for u, v in mst_edges)
            self.text_output.append(f"\nKruskal's MST completed!")
            self.text_output.append(f"Total weight: {total_weight}")
            self.text_output.append(f"MST edges: {sorted(mst_edges)}")
            self.canvas.draw_graph(
                self.graph,
                highlight_edges=mst_edges,
                title="Kruskal's MST - Completed"
            )

        self.algorithm_steps.append(final_step)
        self.timer.start(1000)

    def run_all_pairs_dijkstra(self):
        if not self.graph.nodes:
            QMessageBox.warning(self, "Error", "Graph is empty.")
            return

        self.current_algorithm = "all_pairs_dijkstra"
        self.algorithm_steps = []
        self.current_step = 0

        nodes = sorted(self.graph.nodes())
        n = len(nodes)
        
        # 初始化距离矩阵
        distance_matrix = {source: {} for source in nodes}
        
        self.text_output.append("\n=== All-Pairs Dijkstra Algorithm ===")
        self.text_output.append(f"Nodes: {', '.join(nodes)}")
        
        step_states = []
        step_count = 1

        # 对每个节点运行Dijkstra算法
        for source in nodes:
            self.text_output.append(f"\n--- Running Dijkstra from source: {source} ---")
            
            distances = {node: float('inf') for node in nodes}
            previous = {node: None for node in nodes}
            distances[source] = 0
            pq = [(0, source)]
            visited = set()

            source_steps = []

            while pq:
                current_dist, current_node = heapq.heappop(pq)
                if current_dist > distances[current_node]:
                    continue
                if current_node in visited:
                    continue
                visited.add(current_node)

                # 记录当前状态
                source_steps.append({
                    'step': step_count,
                    'source': source,
                    'current_node': current_node,
                    'current_dist': current_dist,
                    'visited': visited.copy(),
                    'distances': distances.copy(),
                    'previous': previous.copy(),
                    'relaxations': []
                })

                # 松弛操作
                for neighbor in self.graph.neighbors(current_node):
                    weight = self.graph[current_node][neighbor]['weight']
                    alt = current_dist + weight
                    if alt < distances[neighbor]:
                        old_dist = distances[neighbor]
                        distances[neighbor] = alt
                        previous[neighbor] = current_node
                        heapq.heappush(pq, (alt, neighbor))
                        source_steps[-1]['relaxations'].append({
                            'neighbor': neighbor,
                            'old_dist': old_dist,
                            'new_dist': alt,
                            'edge': (current_node, neighbor)
                        })

                step_count += 1

            # 存储该源节点的最终距离
            for target in nodes:
                distance_matrix[source][target] = distances[target]

            # 添加该源节点的所有步骤
            for state in source_steps:
                step_states.append(state)

        # 存储最终距离矩阵
        self.final_distance_matrix = distance_matrix

        # 构建步骤函数
        for state in step_states:
            def make_step(s):
                def step():
                    self.text_output.append(f"\nStep {s['step']}: Source {s['source']}, Process node {s['current_node']} (distance: {s['current_dist']})")
                    
                    # 显示当前源节点的距离向量
                    self.text_output.append(f"Distance vector for source {s['source']}:")
                    for node, dist in s['distances'].items():
                        status = "✓" if node in s['visited'] else " "
                        dist_str = str(dist) if dist != float('inf') else "∞"
                        self.text_output.append(f"  {status} {node}: {dist_str}")
                    
                    # 显示松弛操作
                    if s['relaxations']:
                        self.text_output.append("Relaxations:")
                        for relax in s['relaxations']:
                            self.text_output.append(
                                f"  {s['current_node']}→{relax['neighbor']}: " +
                                f"{relax['old_dist']} → {relax['new_dist']}"
                            )
                    
                    # 构建当前路径边
                    path_edges = []
                    for node in self.graph.nodes:
                        if s['previous'][node] is not None:
                            path_edges.append((s['previous'][node], node))
                    
                    # 绘制图形
                    self.canvas.draw_graph(
                        self.graph,
                        highlight_edges=path_edges,
                        highlight_nodes=s['visited'],
                        title=f"Dijkstra from {s['source']} - Step {s['step']}"
                    )
                return step
            self.algorithm_steps.append(make_step(state))

        def final_step():
            self.text_output.append(f"\n=== All-Pairs Dijkstra Completed ===")
            
            # 显示完整的距离矩阵
            self.text_output.append("Final Distance Matrix:")
            nodes = sorted(self.graph.nodes())
            
            # 表头
            header = "From\\To\t" + "\t".join(nodes)
            self.text_output.append(header)
            
            # 矩阵内容
            for source in nodes:
                row = f"{source}\t"
                for target in nodes:
                    dist = self.final_distance_matrix[source][target]
                    dist_str = str(dist) if dist != float('inf') else "∞"
                    row += f"{dist_str}\t"
                self.text_output.append(row)
            
            # 显示所有最短路径
            self.text_output.append("\nShortest paths:")
            for source in nodes:
                for target in nodes:
                    if source != target and self.final_distance_matrix[source][target] != float('inf'):
                        # 重新计算路径（为了演示）
                        distances = {node: float('inf') for node in nodes}
                        previous = {node: None for node in nodes}
                        distances[source] = 0
                        pq = [(0, source)]
                        
                        while pq:
                            current_dist, current_node = heapq.heappop(pq)
                            if current_node == target:
                                break
                            if current_dist > distances[current_node]:
                                continue
                            for neighbor in self.graph.neighbors(current_node):
                                weight = self.graph[current_node][neighbor]['weight']
                                alt = current_dist + weight
                                if alt < distances[neighbor]:
                                    distances[neighbor] = alt
                                    previous[neighbor] = current_node
                                    heapq.heappush(pq, (alt, neighbor))
                        
                        # 重建路径
                        path = []
                        curr = target
                        while curr is not None:
                            path.append(curr)
                            curr = previous[curr]
                        path.reverse()
                        
                        self.text_output.append(f"{source} → {target}: {self.final_distance_matrix[source][target]} (Path: {' → '.join(path)})")
            
            # 绘制最终图形（显示所有边）
            self.canvas.draw_graph(
                self.graph,
                title="All-Pairs Dijkstra - Completed"
            )
            
            # 更新输入界面的距离矩阵表格
            self.update_distance_table()

        self.algorithm_steps.append(final_step)
        self.timer.start(1000)  # 稍微放慢速度以便观察
    
    def update_distance_table(self):
        """更新输入界面的距离矩阵表格"""
        if self.final_distance_matrix is None:
            return
            
        nodes = sorted(self.graph.nodes())
        n = len(nodes)
        
        # 设置表格行和列
        self.distance_table.setRowCount(n + 1)
        self.distance_table.setColumnCount(n + 1)
        
        # 设置表头
        self.distance_table.setItem(0, 0, QTableWidgetItem("From\\To"))
        for i, node in enumerate(nodes):
            self.distance_table.setItem(0, i + 1, QTableWidgetItem(node))
            self.distance_table.setItem(i + 1, 0, QTableWidgetItem(node))
        
        # 填充距离数据
        for i, source in enumerate(nodes):
            for j, target in enumerate(nodes):
                distance = self.final_distance_matrix[source][target]
                distance_str = str(distance) if distance != float('inf') else "∞"
                self.distance_table.setItem(i + 1, j + 1, QTableWidgetItem(distance_str))
        
        # 调整列宽和行高
        for i in range(n + 1):
            self.distance_table.setColumnWidth(i, 40)
            self.distance_table.setRowHeight(i, 25)
        
        # 设置字体大小
        font = self.distance_table.font()
        font.setPointSize(8)
        self.distance_table.setFont(font)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = GraphApp()
    window.show()
    sys.exit(app.exec())