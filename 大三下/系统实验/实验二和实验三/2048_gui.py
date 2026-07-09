# -*- coding: utf-8 -*-
"""OpenMIPS 2048 图形界面 —— 带移动/融合动画(纯 Python 端,板子不动)
板子照常只发最终棋盘 B:...|S:...|G:...,Python 端:
  1. 复现 2048 移动算法(与板子 C 逻辑一致)
  2. 对比上一帧,反推移动方向
  3. 用 Canvas 播放滑动动画,融合/新增格子做弹出效果
依赖: pyserial
"""
import serial
import threading
import queue
import tkinter as tk

PORT = 'COM5'      # ← 你的串口
BAUD = 4800        # ← CPU 50MHz -> 实际 4800
N = 4
CELL = 84
GAP = 10
PAD = 12
BOARD = PAD * 2 + N * CELL + (N - 1) * GAP
FRAMES = 10        # 滑动总帧数
FRAME_MS = 14      # 每帧间隔(ms)

BG = '#bbada0'
CELL_BG = '#cdc1b4'
COLORS = {
    0:    ('#cdc1b4', '#776e65'),
    2:    ('#eee4da', '#776e65'),
    4:    ('#ede0c8', '#776e65'),
    8:    ('#f2b179', '#f9f6f2'),
    16:   ('#f59563', '#f9f6f2'),
    32:   ('#f67c5f', '#f9f6f2'),
    64:   ('#f65e3b', '#f9f6f2'),
    128:  ('#edcf72', '#f9f6f2'),
    256:  ('#edcc61', '#f9f6f2'),
    512:  ('#edc850', '#f9f6f2'),
    1024: ('#edc53f', '#f9f6f2'),
    2048: ('#edc22e', '#f9f6f2'),
    4096: ('#3c3a32', '#f9f6f2'),
}


def xy(i, j):
    """格子 的左上角像素坐标"""
    return PAD + j * (CELL + GAP), PAD + i * (CELL + GAP)


# ============ 2048 移动算法(与板子一致)============
def _slide(row):
    """对一行做左移,返回 (新行, tracks)。tracks: [(from_col, to_col, merged), ...]"""
    items = [(c, row[c]) for c in range(N) if row[c] != 0]
    new = [0] * N
    tracks = []
    w = 0
    k = 0
    while k < len(items):
        if k + 1 < len(items) and items[k][1] == items[k + 1][1]:
            new[w] = items[k][1] * 2
            tracks.append((items[k][0], w, True))
            tracks.append((items[k + 1][0], w, True))
            w += 1
            k += 2
        else:
            new[w] = items[k][1]
            tracks.append((items[k][0], w, False))
            w += 1
            k += 1
    return new, tracks


def apply_move(grid, d):
    """对整盘沿方向 d 移动,返回 (新盘, moves)。moves[(i,j)] = (to_i, to_j, merged)"""
    new = [r[:] for r in grid]
    moves = {}
    if d == 'left':
        for i in range(N):
            row, tr = _slide(grid[i])
            new[i] = row
            for fc, tc, m in tr:
                moves[(i, fc)] = (i, tc, m)
    elif d == 'right':
        for i in range(N):
            row, tr = _slide(grid[i][::-1])
            new[i] = row[::-1]
            for fc, tc, m in tr:
                moves[(i, N - 1 - fc)] = (i, N - 1 - tc, m)
    elif d == 'up':
        for j in range(N):
            col = [grid[i][j] for i in range(N)]
            nc, tr = _slide(col)
            for i in range(N):
                new[i][j] = nc[i]
            for fr, trow, m in tr:
                moves[(fr, j)] = (trow, j, m)
    elif d == 'down':
        for j in range(N):
            col = [grid[i][j] for i in range(N)][::-1]
            nc, tr = _slide(col)
            nc = nc[::-1]
            for i in range(N):
                new[i][j] = nc[i]
            for fr, trow, m in tr:
                moves[(N - 1 - fr, j)] = (N - 1 - trow, j, m)
    return new, moves


def detect_dir(prev, cur):
    """对比 prev/cur 反推方向,返回 (方向, moves)。无法确定返回 (None, None)"""
    if prev is None or prev == cur:
        return None, None
    best, bd = None, 99
    for d in ['left', 'right', 'up', 'down']:
        mv, _ = apply_move(prev, d)
        diff = sum(1 for i in range(N) for j in range(N) if mv[i][j] != cur[i][j])
        if diff < bd:
            bd, best = diff, d
    if bd <= 1:                       # 只有新加的方块不同 => 命中该方向
        _, moves = apply_move(prev, best)
        return best, moves
    return None, None


class App:
    def __init__(self, root):
        self.root = root
        root.title('OpenMIPS 2048')
        root.configure(bg=BG)

        top = tk.Frame(root, bg=BG)
        top.pack(pady=8)
        tk.Label(top, text='2048', font=('Arial', 28, 'bold'), bg=BG, fg='#776e65').pack(side='left', padx=24)
        self.score_lbl = tk.Label(top, text='0', font=('Arial', 18, 'bold'), bg=BG, fg='#ffffff')
        self.score_lbl.pack(side='left', padx=24)
        self.status = tk.Label(root, text='等待数据...', font=('Arial', 11), bg=BG, fg='#776e65')
        self.status.pack()

        self.cv = tk.Canvas(root, width=BOARD, height=BOARD, bg=BG, highlightthickness=0)
        self.cv.pack(padx=12, pady=10)
        for i in range(N):           # 背景空格
            for j in range(N):
                x, y = xy(i, j)
                self.cv.create_rectangle(x, y, x + CELL, y + CELL, fill=CELL_BG, outline='')

        self.prev = None
        self.animating = False

        try:
            self.ser = serial.Serial(PORT, BAUD, timeout=1)
            self.status.config(text=f'已连接 {PORT}@{BAUD} — 拨板子开关 + 按 N17')
        except Exception as e:
            self.status.config(text=f'串口失败: {e}')
            self.ser = None

        self.q = queue.Queue()
        if self.ser:
            threading.Thread(target=self.reader, daemon=True).start()
        self.root.after(40, self.poll)

    # ---- 串口 ----
    def reader(self):
        while True:
            try:
                line = self.ser.readline().decode('ascii', errors='ignore').strip()
            except Exception:
                continue
            if line.startswith('B:'):
                self.q.put(line)

    def poll(self):
        try:
            while True:
                self.handle(self.q.get_nowait())
        except queue.Empty:
            pass
        self.root.after(40, self.poll)

    def handle(self, line):
        try:
            parts = line[2:].split('|')
            vals = [int(x) for x in parts[0].split(',')]
            score = int(parts[1][2:]) if len(parts) > 1 and parts[1].startswith('S:') else 0
            state = int(parts[2][2:]) if len(parts) > 2 and parts[2].startswith('G:') else 0
            if len(vals) != 16:
                return
            cur = [vals[i * N:(i + 1) * N] for i in range(N)]
        except Exception:
            return

        if self.prev is not None and cur == self.prev:
            return                              # 没变化(无效操作),忽略
        self.score_lbl.config(text=str(score))
        if state:
            self.status.config(text='Game Over! 按 CPU RESET 重开')

        if self.animating:                      # 动画进行中,丢弃中间帧,只记最新
            self.prev = cur
            return

        d, moves = detect_dir(self.prev, cur)
        if d:
            self.animate(self.prev, cur, moves)
        else:
            self.draw(cur, set((i, j) for i in range(N) for j in range(N) if cur[i][j] != 0))
            self.prev = cur

    # ---- 绘制 ----
    def _mk_tile(self, i, j, v):
        x, y = xy(i, j)
        bg, fg = COLORS.get(v, ('#3c3a32', '#f9f6f2'))
        r = self.cv.create_rectangle(x, y, x + CELL, y + CELL, fill=bg, outline='', tags='tile')
        fs = {1: 38, 2: 34, 3: 28, 4: 22}.get(len(str(v)), 20)
        t = self.cv.create_text(x + CELL / 2, y + CELL / 2, text=str(v),
                                font=('Arial', fs, 'bold'), fill=fg, tags='tile')
        return r, t

    def _clear_tiles(self):
        self.cv.delete('tile')

    def draw(self, grid, pop_set):
        """直接绘制 grid;pop_set 里的格子做弹出动画"""
        self._clear_tiles()
        for i in range(N):
            for j in range(N):
                v = grid[i][j]
                if v == 0:
                    continue
                r, t = self._mk_tile(i, j, v)
                if (i, j) in pop_set:
                    cx, cy = xy(i, j)
                    cx += CELL / 2
                    cy += CELL / 2
                    self.cv.scale(r, cx, cy, 0.5, 0.5)
                    self.cv.scale(t, cx, cy, 0.5, 0.5)
                    self.root.after(60, self._pop, r, t, cx, cy)

    def _pop(self, r, t, cx, cy):
        self.cv.scale(r, cx, cy, 2.0, 2.0)
        self.cv.scale(t, cx, cy, 2.0, 2.0)

    # ---- 滑动动画 ----
    def animate(self, prev, cur, moves):
        self.animating = True
        self._clear_tiles()
        anim = []
        for (i, j), (ti, tj, m) in moves.items():
            v = prev[i][j]
            r, t = self._mk_tile(i, j, v)
            fx, fy = xy(i, j)
            tx, ty = xy(ti, tj)
            anim.append((r, t, (tx - fx) / FRAMES, (ty - fy) / FRAMES))
        # 弹出集:cur 相对 prev 变化的格子(融合后值变 / 新增方块)
        pop = set((i, j) for i in range(N) for j in range(N)
                  if cur[i][j] != 0 and prev[i][j] != cur[i][j])
        self._slide_step(anim, 0, cur, pop)

    def _slide_step(self, anim, frame, cur, pop):
        if frame >= FRAMES:
            self.draw(cur, pop)
            self.prev = cur
            self.animating = False
            return
        for r, t, dx, dy in anim:
            self.cv.move(r, dx, dy)
            self.cv.move(t, dx, dy)
        self.root.after(FRAME_MS, self._slide_step, anim, frame + 1, cur, pop)


if __name__ == '__main__':
    root = tk.Tk()
    App(root)
    root.mainloop()
