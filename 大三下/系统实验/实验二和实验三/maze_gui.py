# -*- coding: utf-8 -*-
"""OpenMIPS 走迷宫 图形界面
板子发: M:64个墙值|P:pi,pj|E:ei,ej|W:win
墙值每格 4 bit: 上=1 右=2 下=4 左=8
PC 端: 渲染迷宫墙线 + 玩家(黄) + 终点(绿),玩家移动平滑动画。
依赖: pyserial
"""
import serial
import threading
import queue
import tkinter as tk

PORT = 'COM5'      # ← 改成你的串口
BAUD = 4800        # ← CPU 50MHz -> 4800
N = 8
CELL = 48
PAD = 14
BOARD = PAD * 2 + N * CELL
WALL_W = 3
FRAMES = 8
FRAME_MS = 16

BG = '#222831'
PATH = '#393e46'
WALL_C = '#eeeeee'
PLAYER_C = '#ffd166'
END_C = '#06d6a0'

WUP, WRIGHT, WDOWN, WLEFT = 1, 2, 4, 8


def cell_xy(i, j):
    return PAD + j * CELL, PAD + i * CELL


class App:
    def __init__(self, root):
        self.root = root
        root.title('OpenMIPS Maze')
        root.configure(bg=BG)
        self.status = tk.Label(root, text='等待数据...', font=('Arial', 12), bg=BG, fg='#eeeeee')
        self.status.pack(pady=6)
        self.cv = tk.Canvas(root, width=BOARD, height=BOARD, bg=BG, highlightthickness=0)
        self.cv.pack(padx=12, pady=10)
        for i in range(N):                 # 背景路径格
            for j in range(N):
                x, y = cell_xy(i, j)
                self.cv.create_rectangle(x, y, x + CELL, y + CELL, fill=PATH, outline='', tags='bg')

        self.wall = None
        self.player = (0, 0)
        self.prev_player = None
        self.end = (N - 1, N - 1)
        self.animating = False
        self.win = False

        try:
            self.ser = serial.Serial(PORT, BAUD, timeout=1)
            self.status.config(text=f'已连接 {PORT}@{BAUD} — SW1右/SW2左/SW3下/SW4上 + N17')
        except Exception as e:
            self.status.config(text=f'串口失败: {e}')
            self.ser = None

        self.q = queue.Queue()
        if self.ser:
            threading.Thread(target=self.reader, daemon=True).start()
        self.root.after(40, self.poll)

    def reader(self):
        while True:
            try:
                line = self.ser.readline().decode('ascii', errors='ignore').strip()
            except Exception:
                continue
            if line.startswith('M:'):
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
            wall_vals = [int(x) for x in parts[0].split(',')]
            if len(wall_vals) != N * N:
                return
            new_wall = [wall_vals[i * N:(i + 1) * N] for i in range(N)]
            pp = parts[1][2:].split(',')
            new_player = (int(pp[0]), int(pp[1]))
            if len(parts) > 2 and parts[2].startswith('E:'):
                ep = parts[2][2:].split(',')
                self.end = (int(ep[0]), int(ep[1]))
            win = (len(parts) > 3 and parts[3].startswith('W:') and int(parts[3][2:]) == 1)
        except Exception:
            return

        # 迷宫结构变了(新迷宫) -> 重画墙 + 终点
        if new_wall != self.wall:
            self.wall = new_wall
            self.draw_maze()
            self.win = False
            self.status.config(text=f'已连接 — SW1右/SW2左/SW3下/SW4上 + N17  (走到右下角绿色终点)')

        if self.animating:
            self.player = new_player
            self.prev_player = new_player
            return

        if self.prev_player is not None and new_player != self.prev_player and not self.win:
            self.animate_player(self.prev_player, new_player)
        else:
            self.draw_player(new_player)
        self.prev_player = new_player
        self.player = new_player

        if win and not self.win:
            self.win = True
            self.status.config(text='You win!  按 CPU RESET 重新生成迷宫')

    def draw_maze(self):
        self.cv.delete('wall')
        self.cv.delete('end')
        ei, ej = self.end                      # 终点
        x, y = cell_xy(ei, ej)
        self.cv.create_rectangle(x + 5, y + 5, x + CELL - 5, y + CELL - 5,
                                 fill=END_C, outline='', tags='end')
        for i in range(N):                     # 墙线
            for j in range(N):
                w = self.wall[i][j]
                x, y = cell_xy(i, j)
                if w & WUP:    self.cv.create_line(x, y, x + CELL, y, fill=WALL_C, width=WALL_W, tags='wall')
                if w & WRIGHT: self.cv.create_line(x + CELL, y, x + CELL, y + CELL, fill=WALL_C, width=WALL_W, tags='wall')
                if w & WDOWN:  self.cv.create_line(x, y + CELL, x + CELL, y + CELL, fill=WALL_C, width=WALL_W, tags='wall')
                if w & WLEFT:  self.cv.create_line(x, y, x, y + CELL, fill=WALL_C, width=WALL_W, tags='wall')

    def draw_player(self, pos):
        self.cv.delete('player')
        i, j = pos
        x, y = cell_xy(i, j)
        self.cv.create_oval(x + 7, y + 7, x + CELL - 7, y + CELL - 7,
                            fill=PLAYER_C, outline='', tags='player')

    def animate_player(self, prev, cur):
        self.animating = True
        self.cv.delete('player')
        pi, pj = prev
        x0, y0 = cell_xy(pi, pj)
        r = self.cv.create_oval(x0 + 7, y0 + 7, x0 + CELL - 7, y0 + CELL - 7,
                                fill=PLAYER_C, outline='', tags='player')
        ci, cj = cur
        x1, y1 = cell_xy(ci, cj)
        self._step(r, 0, (x1 - x0) / FRAMES, (y1 - y0) / FRAMES)

    def _step(self, r, frame, dx, dy):
        if frame >= FRAMES:
            self.animating = False
            return
        self.cv.move(r, dx, dy)
        self.root.after(FRAME_MS, self._step, r, frame + 1, dx, dy)


if __name__ == '__main__':
    root = tk.Tk()
    App(root)
    root.mainloop()
