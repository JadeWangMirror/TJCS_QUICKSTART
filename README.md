# 📚 计科速通指南 · TJCS QUICKSTART

> 同济大学 · 计算机科学与技术专业课程资料汇总 —— 教材、课件、笔记、实验与课程设计，一站式速通。

按学期组织，覆盖大二至大三核心课程。部分超大文件通过 **Git LFS** 存储，克隆前请先安装 LFS（见文末说明）。

---

## 🗂️ 目录结构

```
计科速通指南/
├── 大二上/
│   ├── 组合数学/        教材 + PPT（第 1–7 章）+ 期末复习
│   ├── 计科导/          课程概述 / 工具 / 项目参考
│   ├── 数据结构/        平时作业 ↗ 外部仓库
│   └── OOP · 数字逻辑 · 离散/        （待补充）
├── 大二下/
│   ├── AI/              教材 + PPT（hl / wy 两套）+ 专题笔记
│   ├── 计组/            教材 + 王道 + PPT + 复习笔记
│   ├── 数据库/          教材 + 复习笔记（ER / SQL / 关系代数）
│   ├── 算法/            PPT（第 1–17 节）
│   ├── 数据结构课设/    课设计划 + 解包资料
│   └── 拓扑/            教材
├── 大三上/
│   ├── 操作系统/        README + doc/ppt + doc/exam
│   ├── 数据库课设/      README + doc/project + data + video ↗ 外部仓库
│   ├── 机器学习/        README + doc/ppt + doc/assignment + doc/exam
│   ├── 系统结构/        README + doc/textbook + doc/ppt + doc/notes
│   ├── 计算机网络/      README + doc/ppt + doc/lab
│   ├── 软件工程/        README + doc/ppt + doc/project + doc/presentation
│   ├── 随机过程/        README + data + image + doc/project
│   └── 自动机/          README ↗ 外部仓库
└── 大三下/
    ├── 编译原理/        README + doc/ppt + doc/notes
    ├── 中文信息处理/    README ↗ 外部仓库
    ├── 操作系统课设/    README + doc/project ↗ 外部链接待补
    ├── 系统实验/        README + doc/lab + doc/presentation ↗ 外部链接待补
    └── 计网课设/        README ↗ 外部链接待补
```

---

## 🔗 相关项目仓库

部分作业 / 课程设计放在独立仓库中，本指南内对应 `.md` 文件有详细介绍：

| 课程 | 仓库 | 简介 |
| --- | --- | --- |
| 数据结构（大二上） | [Tongji-Data-Structure](https://github.com/hyxtj/Tongji-Data-Structure) | 平时作业 hw1–hw5（C++）+ 讨论课材料 |
| 计科导（大二上） | [Introduction-to-Computer-Science](https://github.com/fluckyflucky/Introduction-to-Computer-Science) | 大作业小组 Web 项目 |
| 数据库课设（大三上） | [Tongji_database_design](https://github.com/hyxtj/Tongji_database_design) | 2025 数据库课程设计（报告 + 前后端 + 数据） |
| 自动机（大三上） | [Formal-Languages-and-Automata-Theory-Tongji](https://github.com/hyxtj/Formal-Languages-and-Automata-Theory-Tongji) | 形式语言与自动机 |
| 中文信息处理（大三下） | [nlp-cws-methods](https://github.com/hyxtj/nlp-cws-methods) | 中文分词对比实验（词典 / HMM / BiLSTM-CRF / BERT） |

---

## 📦 关于大文件（Git LFS）

以下文件超过 GitHub 的 100 MB 单文件上限，使用 [Git LFS](https://git-lfs.github.com) 存储：

- `大二下/AI/doc/textbook/AI教材.pdf`
- `大二下/数据库/doc/textbook/数据库教材.pdf`
- `大三上/系统结构/doc/textbook/计算机系统结构教程.pdf`
- `大三下/编译原理/doc/notes/笔记.pdf`

克隆前请先安装并初始化 LFS：

```bash
git lfs install
git clone https://github.com/JadeWangMirror/TJCS_QUICKSTART.git
```

---

## 📝 说明

- 本仓库仅供学习交流，资料来源于课程与公开渠道，版权归原作者所有。
- 标注「待补充」的课程目录尚未整理资料；Git 不跟踪空目录，添加内容后才会出现在仓库中。
