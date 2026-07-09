# TJCS QUICKSTART

同济大学计算机科学与技术专业课程资料整理仓库。

本仓库按“学期 / 课程名”组织课程资料。每门已整理课程都以课程目录下的 `README.md` 作为统一入口，资料文件按 `doc/`、`image/`、`data/` 等类型目录归档。完整课程项目、课设源码和大作业源码不直接放入本仓库，统一以外部仓库链接或说明链接维护。

## 快速开始

克隆仓库前建议先安装并启用 Git LFS，部分教材和笔记超过 GitHub 单文件限制，已使用 LFS 管理。

```bash
git lfs install
git clone https://github.com/JadeWangMirror/TJCS_QUICKSTART.git
```

进入任意课程目录后，优先阅读该目录下的 `README.md`。课程 README 会说明已有资料、文件位置、项目链接和待补充内容。

## 目录概览

| 学期 | 课程 |
| --- | --- |
| 大二上 | 数据结构、组合数学、计科导 |
| 大二下 | AI、拓扑、数据库、数据结构课设、算法、计组 |
| 大三上 | 操作系统、数据库课设、机器学习、系统结构、自动机、计算机网络、软件工程、随机过程 |
| 大三下 | 中文信息处理、操作系统课设、系统实验、编译原理、计网课设 |

## 资料结构

课程目录遵循以下基本结构。没有对应资料时，不需要创建空目录。

```text
学期/课程名/
├── README.md
├── doc/
│   ├── textbook/      # 教材、参考书、讲义
│   ├── ppt/           # 课件、课堂 PPT
│   ├── notes/         # 笔记、复习资料、知识点整理
│   ├── exam/          # 试卷、答案、考纲、期中期末资料
│   ├── lab/           # 实验指导、实验报告、实验材料说明
│   └── project/       # 课设报告、展示文档、项目说明
├── image/             # 图片、截图、图表
├── data/              # 数据集、表格、样例输入输出
└── archive/           # 历史归档或暂不拆分的压缩资料
```

项目源码、实验源码、前后端工程、构建产物、运行数据和演示视频默认不直接入仓。确需说明时，在课程 README 的“课程项目参考”或“备注”中放外部链接。

## 已整理重点

| 学期 | 说明 |
| --- | --- |
| 大二上 | 组合数学、计科导、数据结构已按课程 README 和 `doc/` 结构整理。 |
| 大二下 | AI、计组、数据库、算法、拓扑、数据结构课设已完成资料归档；项目类内容以链接形式维护。 |
| 大三上 | 操作系统、系统结构、计算机网络、机器学习、软件工程、随机过程等已拆分课件、考试、作业和项目说明。 |
| 大三下 | 编译原理、系统实验、操作系统课设、计网课设、中文信息处理已补齐 README，并清理直接入仓的项目源码和二进制产物。 |

## 相关项目

部分作业、课程设计或完整项目维护在独立仓库中。

| 课程 | 仓库 | 简介 |
| --- | --- | --- |
| 数据结构（大二上） | [Tongji-Data-Structure](https://github.com/hyxtj/Tongji-Data-Structure) | 平时作业与讨论课材料 |
| 计科导（大二上） | [Introduction-to-Computer-Science](https://github.com/fluckyflucky/Introduction-to-Computer-Science) | 大作业小组 Web 项目 |
| 数据库课设（大三上） | [Tongji_database_design](https://github.com/hyxtj/Tongji_database_design) | 数据库课程设计项目 |
| 自动机（大三上） | [Formal-Languages-and-Automata-Theory-Tongji](https://github.com/hyxtj/Formal-Languages-and-Automata-Theory-Tongji) | 形式语言与自动机课程资料 |
| 中文信息处理（大三下） | [nlp-cws-methods](https://github.com/hyxtj/nlp-cws-methods) | 中文分词方法对比实验 |

## Git LFS

以下文件超过 GitHub 的 100 MB 单文件限制，使用 Git LFS 存储：

| 文件 | 说明 |
| --- | --- |
| `大二下/AI/doc/textbook/AI教材.pdf` | AI 教材 |
| `大二下/数据库/doc/textbook/数据库教材.pdf` | 数据库教材 |
| `大三上/系统结构/doc/textbook/计算机系统结构教程.pdf` | 系统结构教材 |
| `大三下/编译原理/doc/notes/笔记.pdf` | 编译原理笔记 |

如果克隆后看到的是 LFS 指针文件，执行：

```bash
git lfs pull
```

## 维护规范

- 每门课程必须保留一个 `README.md`，作为该课程唯一说明入口。
- 课程目录下零散的 Markdown 或 txt 说明应合并进课程 README。
- 文档类资料优先放入 `doc/`，并按 `textbook`、`ppt`、`notes`、`exam`、`lab`、`project` 继续细分。
- 完整项目源码、课程设计源码、作业源码不直接提交到本仓库，应改为外部仓库链接。
- 移动 LFS 管理的大文件后，需要同步更新 `.gitattributes` 和根 README 的 LFS 列表。
- 更详细的协作规则见 [AGENT.md](./AGENT.md)。

## 说明

本仓库仅供学习交流使用。资料来源于课程学习、个人整理和公开渠道，版权归原作者所有。若有侵权或不适合公开的内容，请提交 issue 或联系维护者处理。
