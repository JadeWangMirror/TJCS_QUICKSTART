# 课程表管理系统 (Smart Course Scheduler)

## 项目概述

课程表管理系统是一个基于 Vue 3 + TypeScript 的现代化全栈 Web 应用，集成了课程管理、用户认证以及**深度定制的 AI 智能助手**功能。该项目不仅仅是一个简单的增删改查工具，而是采用**RAG（检索增强生成）技术和混合搜索架构**的智能教学辅助平台。前端使用 Vue 3 Composition API 构建响应式界面，后端使用 Python Flask 提供 RESTful API 及 AI 编排服务，数据存储采用 SQLite 数据库。

## 项目结构

```
.
├── backend
│   ├── app.py              # Flask后端服务主文件，API路由、AI RAG逻辑及向量计算
│   └── database.sql        # 数据库初始化脚本
├── frontend
│   ├── src
│   │   ├── components      # Vue 3组件库
│   │   │   ├── AIAdvisor.vue        # AI智能助手组件（支持渲染交互式卡片）
│   │   │   ├── CourseList.vue       # 课程列表（集成混合搜索栏）
│   │   │   ├── CourseSquare.vue     # 课程广场
│   │   │   ├── Login.vue            # 用户认证
│   │   │   ├── Timetable.vue        # 课表可视化
│   │   │   └── UserProfile.vue      # 用户资料
│   │   ├── App.vue         # 主入口
│   │   ├── main.ts         # TypeScript入口
│   │   └── types.ts        # 类型定义
│   ├── index.html          # HTML入口
│   ├── package.json        # 依赖配置
│   └── vite.config.ts      # Vite配置
└── ...

```

## 技术栈

### 前端技术栈

* **Vue 3**: 使用 Composition API 构建响应式逻辑
* **TypeScript**: 强类型约束，确保数据接口（特别是 AI 返回的结构化数据）的安全性
* **Vite**: 极速构建与热更新
* **UI/UX**: CSS Grid/Flexbox 布局，针对聊天流和课表视图的定制化样式

### 后端技术栈

* **Python Flask**: RESTful API 服务及 AI 逻辑编排
* **SQLite**: 关系型数据存储
* **PyJWT**: 身份验证
* **LangChain / OpenAI API**: 大模型调用与上下文管理
* **Vector Logic**: 基于 Transformer 的文本向量化处理与相似度计算（NumPy/Torch）

## 核心功能

### 1. 多维度智能课程搜索

系统摒弃了传统的单一模糊查询，实现了三位一体的混合搜索体验：

* **精准检索**：基于关键字的传统数据库查询。
* **语义理解**：利用 Transformer 模型将查询意图向量化，捕捉“简单的数学课”与“初等微积分”之间的语义关联。
* **智能联想**：当用户输入模糊概念时，AI 自动联想相关专业术语进行检索增强。

### 2. RAG 驱动的 AI 课程顾问

* **情境感知**：AI 不仅回答问题，还能读取用户的当前课表、已修学分和空闲时间段。
* **交互式决策**：AI 输出不仅仅是文本，还能返回可点击的“操作卡片”（Action Card），实现对话即操作。

### 3. 可视化课表管理与认证

* 动态课表渲染，冲突检测可视化。
* JWT 全流程安全认证，保护用户隐私数据。

## 技术亮点（深度解析）

### 1. 多模态混合搜索架构 (Hybrid Search Engine)

本项目在课程检索模块引入了业界先进的混合搜索策略，旨在解决“用户不知道课程准确名称”的痛点。系统并行执行以下三种搜索方式，并对结果进行加权融合：

* **L1: 传统关键字搜索 (Keyword Search)**
* 利用 SQL 的 LIKE 语句或全文索引技术，解决精确匹配需求（如搜索课程代码 "CS101"）。


* **L2: AI 联想关键字检索 (AI Associative Retrieval)**
* 针对用户输入的模糊口语（如“适合新手的编程课”），先通过 LLM 进行预处理，提取出标准化的搜索关键词（如 "Introduction", "Programming", "Python"），再进行二次检索，扩大召回范围。


* **L3: 基于 Transformer 的向量语义检索 (Vector Semantic Search)**
* **原理**：使用预训练的 Transformer 模型（Encoder-only 架构）将用户查询语句（Query）和数据库中的课程描述（Doc）转换为高维稠密向量（Embeddings）。
* **计算**：在内存中计算查询向量与课程向量的**点积 (Dot Product)** 或余弦相似度。
* **排序**：根据计算出的相似度得分进行排序，取 **TopK** 结果。这使得系统能够理解语义，即使没有关键词重合（如搜“关于钱的课”能搜出“宏观经济学”），也能精准推荐。



### 2. 场景化 RAG 与交互式 AI (Scenario-based RAG & Interactive Agent)

本系统的 AI 模块（`AIAdvisor.vue` + 后端逻辑）超越了普通的 ChatBot，采用了 **RAG（检索增强生成）** 技术，并实现了**结构化输出**：

* **动态上下文注入 (Dynamic Context Injection)**
* 在用户提问时，系统不只发送 Prompt，还会实时检索用户的**私有数据**（当前已选课程、空闲时间槽、历史成绩等）作为 Context 一并喂给 LLM。
* *场景示例*：用户问“周五下午我能选什么课？”，系统会将用户周五下午的空闲时间段数据检索出来注入 Prompt，确保 AI 不会推荐时间冲突的课程。


* **系统提示词工程 (System Prompt Engineering)**
* 精心设计的 System Prompt 规定了 AI 的角色是“专业的教务顾问”，并严格限制其回答必须基于提供的 RAG 数据，杜绝幻觉。


* **可交互式回答 (Actionable Responses)**
* AI 的输出包含两部分：对用户的自然语言回复 + **结构化指令数据 (JSON)**。
* 前端 `AIAdvisor` 组件会解析 JSON，在对话框中渲染出 **“一键选课方案”** 或 **“课程对比卡片”**。
* *体验升级*：用户不再需要记住课程名去列表里搜，直接点击对话气泡中的“添加到课表”按钮，即可完成选课操作，真正实现了**对话即服务 (Conversation as a Service)**。



### 3. 前后端分离与类型安全

* 采用 Vue 3 + Flask 分离架构，通过 RESTful API 通信。
* TypeScript 定义了完善的 `Interface`，特别是针对 AI 返回的复杂的 JSON 结构（如推荐列表、冲突警告）进行了严格的类型定义，极大减少了运行时错误。

### 4. 数据安全与隐私

* **JWT 身份验证**：确保只有授权用户才能访问其个人课表和 AI 对话历史。
* **API 密钥保护**：OpenAI API Key 仅在后端存储和调用，通过后端代理模式服务前端，杜绝密钥泄露风险。

## 性能与扩展

* **向量计算优化**：针对课程数据量级，采用 NumPy 进行高效的矩阵运算，确保 TopK 推荐的毫秒级响应。
* **状态管理**：利用 Vue 3 `reactive` 和 `ref` 实时同步 AI 推荐状态与课表视图，实现“AI 推荐 -> 课表预览”的无缝联动。

## 项目特色总结

本项目通过引入 **Transformer 向量检索** 和 **RAG 上下文感知** 技术，将传统的教务管理系统升级为智能化的**AI 教学助手**。它不仅听得懂用户的模糊需求，还能根据用户的实际课表情况，提供可直接操作的选课建议，极大地提升了选课效率和用户体验。