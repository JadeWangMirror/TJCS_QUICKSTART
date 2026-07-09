"""
零件树拆装模拟器 — 中文节点 + 拆除/安装按钮 + 自动重置 + 汽车零件树
安装逻辑：安装顺序 = 拆除顺序反向
布局逻辑：父节点居中，避免交错，美观树形
"""

import sys, json
from PySide6.QtCore import Qt, QTimer, QPointF, QPropertyAnimation, QEasingCurve
from PySide6.QtGui import (
    QStandardItemModel, QStandardItem, QAction,
    QColor, QFont, QPainter, QPen
)
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QTreeView,
    QVBoxLayout, QListWidget, QHBoxLayout, QPushButton,
    QFileDialog, QLabel, QGraphicsView, QGraphicsScene,
    QGraphicsItem, QGraphicsEllipseItem, QGraphicsTextItem,
    QGraphicsLineItem, QSplitter, QFormLayout, QComboBox,
    QToolBar, QSpinBox, QFrame
)

# ---------- Data model ----------
def sample_product_car():
    """更复杂的汽车零件结构（独立零件但有顺序）"""
    return [
        {"id": "P1", "name": "整车", "pid": None},
        {"id": "A1", "name": "发动机", "pid": "P1"},
        {"id": "A2", "name": "底盘", "pid": "P1"},
        {"id": "A3", "name": "车身", "pid": "P1"},
        {"id": "B1", "name": "曲轴", "pid": "A1"},
        {"id": "B2", "name": "活塞组", "pid": "A1"},
        {"id": "B3", "name": "燃油系统", "pid": "A1"},
        {"id": "B4", "name": "冷却系统", "pid": "A1"},
        {"id": "C1", "name": "车轮", "pid": "A2"},
        {"id": "C2", "name": "悬挂系统", "pid": "A2"},
        {"id": "C3", "name": "刹车系统", "pid": "A2"},
        {"id": "D1", "name": "车门", "pid": "A3"},
        {"id": "D2", "name": "挡风玻璃", "pid": "A3"},
        {"id": "D3", "name": "座椅", "pid": "A3"},
        {"id": "D4", "name": "内饰", "pid": "A3"},
        {"id": "E1", "name": "电池", "pid": "P1"},
        {"id": "E2", "name": "控制单元", "pid": "P1"},
    ]

def build_tree_from_list(nodes_list):
    nodes = {n["id"]: {"id": n["id"], "name": n["name"], "pid": n.get("pid"), "children": []} for n in nodes_list}
    root_ids = []
    for n in nodes.values():
        pid = n["pid"]
        if pid and pid in nodes:
            nodes[pid]["children"].append(n["id"])
        else:
            root_ids.append(n["id"])
    return nodes, root_ids

def compute_disassembly_sequence(nodes, root_ids, target_id):
    """后序遍历：先拆子件，再拆父件"""
    seq = []
    def dfs(u):
        for ch in nodes[u]["children"]:
            dfs(ch)
        seq.append(u)
    dfs(target_id)
    return seq

def compute_assembly_sequence(nodes, root_ids, target_id):
    """安装顺序 = 拆除顺序反过来"""
    dis_seq = compute_disassembly_sequence(nodes, root_ids, target_id)
    return list(reversed(dis_seq))

# ---------- Graphics items ----------
class PartGraphicsNode(QGraphicsEllipseItem):
    RADIUS = 35
    def __init__(self, node_id, name, pos):
        super().__init__(-self.RADIUS, -self.RADIUS, self.RADIUS*2, self.RADIUS*2)
        self.node_id = node_id
        self.setBrush(QColor("#4C9F70"))
        self.setFlag(QGraphicsItem.ItemIsMovable, True)
        self.setFlag(QGraphicsItem.ItemSendsScenePositionChanges, True)
        self.setZValue(1)

        # label
        self.text = QGraphicsTextItem(name, parent=self)
        self.text.setDefaultTextColor(Qt.white)
        font = QFont(); font.setPointSize(9)
        self.text.setFont(font)
        self.text.setPos(-self.RADIUS + 4, -6)

        self.default_color = QColor("#4C9F70")
        self.highlight_color = QColor("#FFB020")
        self.removed_color = QColor("#9E9E9E")

    def highlight(self):
        self.setBrush(self.highlight_color)
        anim = QPropertyAnimation(self, b"scale")
        anim.setStartValue(1.0)
        anim.setEndValue(1.15)
        anim.setDuration(250)
        anim.setEasingCurve(QEasingCurve.OutBack)
        anim.start()
        self._anim = anim

    def reset_style(self):
        self.setBrush(self.default_color)
        self.setOpacity(1.0)
        self.setScale(1.0)

    def mark_removed(self):
        self.setBrush(self.removed_color)
        fade = QPropertyAnimation(self, b"opacity")
        fade.setStartValue(1.0)
        fade.setEndValue(0.3)
        fade.setDuration(600)
        fade.start()
        self._fade = fade

    def itemChange(self, change, value):
        if change == QGraphicsItem.ItemPositionChange and hasattr(self, "edges"):
            for e in self.edges: e.update_positions()
        return super().itemChange(change, value)

class PartGraphicsEdge(QGraphicsLineItem):
    def __init__(self, start, end):
        super().__init__()
        self.start, self.end = start, end
        self.setPen(QPen(QColor("#cccccc"), 2))
        self.setZValue(0)
        self.update_positions()
        if not hasattr(start, "edges"): start.edges = []
        if not hasattr(end, "edges"): end.edges = []
        start.edges.append(self); end.edges.append(self)

    def update_positions(self):
        p1, p2 = self.start.pos(), self.end.pos()
        self.setLine(p1.x(), p1.y(), p2.x(), p2.y())

# ---------- Main ----------
class AssemblySimulator(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("零件树拆装模拟器")
        self.resize(1200, 700)
        self.nodes, self.root_ids = {}, []
        self.graphics_nodes, self.graphics_edges = {}, []
        self.current_steps, self.current_step_index = [], -1
        self.timer = QTimer(self); self.timer.setInterval(900)
        self._setup_ui()
        self.load_sample()
        self._apply_styles()   # 美化 UI

    def _setup_ui(self):
        toolbar = QToolBar("Main"); self.addToolBar(toolbar)
        load_act = QAction("载入 JSON", self); load_act.triggered.connect(self.load_json)
        save_act = QAction("保存 JSON", self); save_act.triggered.connect(self.save_json)
        toolbar.addAction(load_act); toolbar.addAction(save_act)

        splitter = QSplitter(Qt.Horizontal); self.setCentralWidget(splitter)

        # 左侧树
        left = QWidget(); left_layout = QVBoxLayout(left)
        lbl_tree = QLabel("零件树"); lbl_tree.setStyleSheet("font-weight:bold;")
        left_layout.addWidget(lbl_tree)
        self.tree_model = QStandardItemModel()
        self.tree_model.setHorizontalHeaderLabels(["零件"])
        self.tree_view = QTreeView(); self.tree_view.setModel(self.tree_model)
        self.tree_view.clicked.connect(self.on_tree_selected)
        left_layout.addWidget(self.tree_view)
        splitter.addWidget(left)

        # 中间图形
        center = QWidget(); c_layout = QVBoxLayout(center)
        lbl_graph = QLabel("图形化视图"); lbl_graph.setStyleSheet("font-weight:bold;")
        c_layout.addWidget(lbl_graph)
        self.scene = QGraphicsScene(); self.view = QGraphicsView(self.scene)
        self.view.setRenderHints(QPainter.Antialiasing | QPainter.TextAntialiasing)
        c_layout.addWidget(self.view)
        splitter.addWidget(center)

        # 右侧控制
        right = QWidget(); r_layout = QVBoxLayout(right)
        lbl_ctrl = QLabel("控制面板"); lbl_ctrl.setStyleSheet("font-weight:bold;")
        r_layout.addWidget(lbl_ctrl)

        form = QFormLayout()
        self.target_combo = QComboBox(); form.addRow("目标零件:", self.target_combo)
        self.speed_spin = QSpinBox(); self.speed_spin.setRange(200,3000); self.speed_spin.setValue(900)
        self.speed_spin.valueChanged.connect(lambda v: self.timer.setInterval(v))
        form.addRow("步进间隔 ms:", self.speed_spin)
        r_layout.addLayout(form)

        # 操作按钮区
        btns = QHBoxLayout()
        self.btn_dis = QPushButton("拆除"); self.btn_dis.clicked.connect(self.do_disassemble)
        self.btn_ass = QPushButton("安装"); self.btn_ass.clicked.connect(self.do_assemble)
        self.btn_reset = QPushButton("重置"); self.btn_reset.clicked.connect(self.reset_simulation)
        btns.addWidget(self.btn_dis); btns.addWidget(self.btn_ass); btns.addWidget(self.btn_reset)
        r_layout.addLayout(btns)

        # 自动播放
        self.btn_auto = QPushButton("自动播放"); self.btn_auto.setCheckable(True)
        self.btn_auto.clicked.connect(self.toggle_auto)
        r_layout.addWidget(self.btn_auto)

        # 分隔线
        line = QFrame(); line.setFrameShape(QFrame.HLine); line.setFrameShadow(QFrame.Sunken)
        r_layout.addWidget(line)

        # 步骤显示
        r_layout.addWidget(QLabel("步骤顺序"))
        self.steps_list = QListWidget(); r_layout.addWidget(self.steps_list,1)

        splitter.addWidget(right)
        splitter.setSizes([250, 650, 300])

    # ---------- 样式美化 ----------
    def _apply_styles(self):
        self.setStyleSheet("""
            QMainWindow {
                background: #F5F7FA;
            }
            QLabel {
                font-family: "Microsoft YaHei";
                font-size: 14px;
            }
            QTreeView {
                background: #ffffff;
                border: 1px solid #d0d0d0;
                border-radius: 6px;
                padding: 4px;
            }
            QTreeView::item {
                padding: 4px;
            }
            QTreeView::item:hover {
                background: #E8F5E9;
            }
            QListWidget {
                background: #ffffff;
                border: 1px solid #d0d0d0;
                border-radius: 6px;
            }
            QPushButton {
                background: #4C9F70;
                color: white;
                border-radius: 8px;
                padding: 6px 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: #5BB47F;
            }
            QPushButton:checked {
                background: #FFB020;
            }
            QComboBox, QSpinBox {
                background: #ffffff;
                border: 1px solid #cccccc;
                border-radius: 6px;
                padding: 4px;
            }
            QGraphicsView {
                background: #fafafa;
                border: 1px solid #e0e0e0;
                border-radius: 8px;
            }
            QToolBar {
                background: #ffffff;
                border-bottom: 1px solid #d0d0d0;
                padding: 4px;
            }
        """)

    # ---------- Data ----------
    def load_sample(self):
        self.nodes,self.root_ids = build_tree_from_list(sample_product_car())
        self.populate_tree_view(); self.populate_target_combo(); self.redraw_graph()

    def load_json(self):
        path,_=QFileDialog.getOpenFileName(self,"载入 JSON","","JSON Files (*.json)")
        if not path: return
        with open(path,"r",encoding="utf-8") as f: nodes_list=json.load(f)
        self.nodes,self.root_ids=build_tree_from_list(nodes_list)
        self.populate_tree_view(); self.populate_target_combo(); self.redraw_graph()

    def save_json(self):
        path,_=QFileDialog.getSaveFileName(self,"保存 JSON","","JSON Files (*.json)")
        if not path: return
        with open(path,"w",encoding="utf-8") as f: json.dump(list(self.nodes.values()),f,ensure_ascii=False,indent=2)

    # ---------- UI Helpers ----------
    def populate_tree_view(self):
        self.tree_model.removeRows(0,self.tree_model.rowCount())
        def add_items(parent,node_id):
            node=self.nodes[node_id]; item=QStandardItem(node['name'])
            parent.appendRow(item)
            for ch in node["children"]: add_items(item,ch)
        for rid in self.root_ids: add_items(self.tree_model,rid)

    def populate_target_combo(self):
        self.target_combo.clear()
        for nid,node in self.nodes.items():
            self.target_combo.addItem(node['name'],nid)

    def redraw_graph(self):
        """美观的树形布局：父节点居中，避免交错"""
        self.scene.clear(); self.graphics_nodes.clear(); self.graphics_edges.clear()
        level_ygap = 120
        node_size = 100

        def layout(node_id, depth):
            children = self.nodes[node_id]["children"]
            if not children:
                return node_size, {node_id: (0, depth * level_ygap)}

            widths, positions = [], {}
            total_width = 0
            for ch in children:
                w, pos_map = layout(ch, depth+1)
                widths.append((ch, w, pos_map))
                total_width += w

            offset = - total_width/2
            positions[node_id] = (0, depth * level_ygap)
            for ch, w, pos_map in widths:
                child_center = offset + w/2
                dx = child_center
                for k,(x,y) in pos_map.items():
                    positions[k] = (x+dx, y)
                positions[ch] = (dx, (depth+1)*level_ygap)
                offset += w
            return total_width, positions

        for i,rid in enumerate(self.root_ids):
            _, pos_map = layout(rid, 0)
            for nid,(x,y) in pos_map.items():
                g = PartGraphicsNode(nid, self.nodes[nid]["name"], QPointF(x+i*400, y))
                g.setPos(QPointF(x+i*400, y))
                self.scene.addItem(g)
                self.graphics_nodes[nid] = g
            for nid in pos_map:
                for ch in self.nodes[nid]["children"]:
                    edge = PartGraphicsEdge(self.graphics_nodes[nid], self.graphics_nodes[ch])
                    self.scene.addItem(edge)
                    self.graphics_edges.append(edge)

    # ---------- Simulation ----------
    def plan_steps(self, mode):
        target_id=self.target_combo.currentData()
        if not target_id: return
        if mode=="dis":
            self.current_steps=compute_disassembly_sequence(self.nodes,self.root_ids,target_id)
        else:
            self.current_steps=compute_assembly_sequence(self.nodes,self.root_ids,target_id)
        self.current_step_index=-1
        self.steps_list.clear()
        for s in self.current_steps: self.steps_list.addItem(self.nodes[s]['name'])
        for g in self.graphics_nodes.values(): g.reset_style()

    def apply_step(self,node_id,mode):
        g=self.graphics_nodes[node_id]
        g.highlight()
        if mode=="dis": g.mark_removed()

    def do_disassemble(self):
        self.plan_steps("dis")
        self.timer.timeout.disconnect(); self.timer.timeout.connect(lambda: self.step_play("dis"))
        self.timer.start()

    def do_assemble(self):
        self.plan_steps("ass")
        self.timer.timeout.disconnect(); self.timer.timeout.connect(lambda: self.step_play("ass"))
        self.timer.start()

    def step_play(self,mode):
        if self.current_step_index+1 < len(self.current_steps):
            self.current_step_index += 1
            nid=self.current_steps[self.current_step_index]
            self.apply_step(nid,mode)
            self.steps_list.setCurrentRow(self.current_step_index)
        else:
            self.timer.stop(); self.btn_auto.setChecked(False)

    def toggle_auto(self,checked):
        if not checked: self.timer.stop()

    def reset_simulation(self):
        self.timer.stop()
        self.btn_auto.setChecked(False)
        for g in self.graphics_nodes.values(): g.reset_style()
        self.steps_list.clear()
        self.current_steps=[]; self.current_step_index=-1

    def on_tree_selected(self,index):
        nid=self.target_combo.itemData(self.target_combo.findText(index.data()))
        if nid: self.target_combo.setCurrentIndex(self.target_combo.findData(nid))
        self.reset_simulation()

# ---------- main ----------
def main():
    app=QApplication(sys.argv)
    win=AssemblySimulator(); win.show()
    sys.exit(app.exec())

if __name__=="__main__": main()
