# 课程表管理系统数据库设计报告

## 1. 引言

### 1.1 项目概述

课程表管理系统是一个基于Vue 3 + TypeScript的现代化全栈Web应用，集成了课程管理、用户认证以及深度定制的AI智能助手功能。该项目采用RAG（检索增强生成）技术和混合搜索架构的智能教学辅助平台，前端使用Vue 3 Composition API构建响应式界面，后端使用Python Flask提供RESTful API及AI编排服务，数据存储采用SQLite数据库。

### 1.2 报告目的

本报告旨在详细阐述课程表管理系统的数据库设计过程，包括需求分析、概念设计、逻辑设计和物理设计四个阶段，确保系统能够高效、稳定地存储和管理用户信息、课程数据、课表安排以及AI交互记录。

### 1.3 项目背景

传统的课程表管理往往依赖纸质文档或简单的电子表格，难以满足现代教学环境中的复杂需求。本系统通过整合AI技术，提供智能课程推荐功能，帮助学生快速找到符合自己需求的课程，并通过可视化课表展示，优化学习安排。

## 2. 需求分析

### 2.1 功能需求分析

#### 2.1.1 用户管理模块

- **用户注册与登录**：系统需要支持用户注册功能，记录用户的邮箱、密码、姓名和头像等信息。用户登录时需要验证身份，确保数据安全。
- **用户资料管理**：允许用户查看和修改个人资料，包括姓名、头像等信息。

#### 2.1.2 课程管理模块

- **课程信息存储**：系统需要存储课程的基本信息，包括课程ID、课程名称、授课教师、排课信息（上课时间、地点、周次）等。
- **课程搜索与推荐**：支持多维度智能课程搜索，包括关键字搜索、语义理解搜索和AI联想搜索。
- **CSV数据处理**：系统从`filtered_courses.csv`文件中加载课程数据，并将其解析为结构化数据。

#### 2.1.3 课表管理模块

- **课表创建与保存**：用户可以创建多个课表，为每个课表命名和添加描述。
- **课表可视化**：系统需要存储用户当前的课表配置，以便在不同设备和会话间保持一致的显示效果。

#### 2.1.4 AI交互模块

- **AI聊天历史记录**：系统需要记录用户与AI助手的交互历史，包括用户问题和AI回答。
- **会话管理**：支持多会话管理，确保用户可以在不同话题间切换。

#### 2.1.5 用户偏好管理

- **收藏课程管理**：用户可以收藏感兴趣的课程，系统需要记录这些收藏信息。

### 2.2 非功能需求分析

#### 2.2.1 性能需求

- 数据库查询响应时间应控制在100ms以内
- 支持并发用户访问
- 课程搜索功能应支持向量语义搜索，提供智能化的推荐结果

#### 2.2.2 安全需求

- 用户密码必须加密存储
- 实现JWT认证机制，保护用户数据安全
- 实现数据访问权限控制

#### 2.2.3 可扩展性需求

- 数据库结构应支持未来功能扩展
- 支持数据备份和恢复机制

### 2.3 数据流分析

系统数据流主要包括：

1. 用户注册/登录流程：用户输入信息 → 数据库验证 → 返回认证结果
2. 课程搜索流程：用户输入查询 → 智能搜索算法 → 数据库匹配 → 返回结果
3. 课表管理流程：用户操作 → 数据更新 → 数据库存储 → 界面刷新
4. AI交互流程：用户提问 → AI处理 → 历史记录存储 → 返回结果

## 3. 数据库概念设计

### 3.1 实体识别

根据需求分析，系统涉及的主要实体包括：

#### 3.1.1 用户实体（User）

- **属性**：ID、邮箱、密码哈希、姓名、头像URL、创建时间
- **主键**：ID
- **约束**：邮箱唯一

#### 3.1.2 课表实体（Timetable）

- **属性**：ID、用户ID、名称、描述、课程信息（JSON格式）、创建时间
- **主键**：ID
- **外键**：用户ID（关联用户实体）

#### 3.1.3 AI聊天历史实体（AI Chat History）

- **属性**：ID、用户ID、会话ID、消息角色、消息内容、时间戳
- **主键**：ID
- **外键**：用户ID（关联用户实体）

#### 3.1.4 用户收藏实体（User Favorite）

- **属性**：ID、用户ID、课程ID、课程名称、课程信息（JSON格式）、创建时间
- **主键**：ID
- **外键**：用户ID（关联用户实体）
- **约束**：用户ID和课程ID组合唯一

#### 3.1.5 课程实体（Course）

- **属性**：ID、名称、排课信息、教师、上课时间地点
- **说明**：课程数据主要来源于CSV文件，内存中处理

### 3.2 实体关系分析

#### 3.2.1 用户与课表关系

- 一个用户可以拥有多个课表（1:N关系）
- 当用户删除时，其所有课表也应被删除（级联删除）

#### 3.2.2 用户与AI聊天历史关系

- 一个用户可以有多条AI聊天记录（1:N关系）
- 当用户删除时，其所有聊天记录也应被删除（级联删除）

#### 3.2.3 用户与收藏课程关系

- 一个用户可以收藏多个课程（1:N关系）
- 一个课程可以被多个用户收藏（N:M关系，通过用户收藏实体实现）

#### 3.2.4 课程与用户的关系

- 课程信息存储在内存中，与用户选择的课表相关联
- 课程数据通过CSV文件加载，不直接存储在SQLite中

### 3.3 E-R图设计

```
    用户实体
┌─────────────────┐
│ id (PK)         │
│ email (UNIQUE)  │
│ password_hash   │
│ full_name       │
│ avatar_url      │
│ created_at      │
└─────────────────┘
         │
         │ (1)
         │
         │ (N)
┌─────────────────┐
│ 课表实体        │
├─────────────────┤
│ id (PK)         │
│ user_id (FK)    │
│ name            │
│ description     │
│ courses (JSON)  │
│ created_at      │
└─────────────────┘
         │
         │ (1)
         │
         │ (N)
┌─────────────────┐
│ AI聊天历史实体  │
├─────────────────┤
│ id (PK)         │
│ user_id (FK)    │
│ session_id      │
│ message_role    │
│ message_content │
│ timestamp       │
└─────────────────┘
```

## 4. 数据库逻辑设计

### 4.1 关系模式设计

#### 4.1.1 用户表 (users)

- **关系模式**：Users(ID, email, password_hash, full_name, avatar_url, created_at)
- **主键**：ID
- **约束**：email唯一

```
Users(ID: INTEGER, email: VARCHAR(255), password_hash: VARCHAR(255), 
      full_name: VARCHAR(255), avatar_url: VARCHAR(500), created_at: DATETIME)
```

#### 4.1.2 课表表 (timetables)

- **关系模式**：Timetables(ID, user_id, name, description, courses, created_at)
- **主键**：ID
- **外键**：user_id → Users(ID) [ON DELETE CASCADE]

```
Timetables(ID: INTEGER, user_id: INTEGER, name: VARCHAR(255), 
           description: TEXT, courses: TEXT, created_at: DATETIME)
```

#### 4.1.3 AI聊天历史表 (ai_chat_history)

- **关系模式**：AI_Chat_History(ID, user_id, session_id, message_role, message_content, timestamp)
- **主键**：ID
- **外键**：user_id → Users(ID) [ON DELETE CASCADE]

```
AI_Chat_History(ID: INTEGER, user_id: INTEGER, session_id: VARCHAR(255), 
                message_role: VARCHAR(50), message_content: TEXT, timestamp: DATETIME)
```

#### 4.1.4 用户收藏表 (user_favorites)

- **关系模式**：User_Favorites(ID, user_id, course_id, course_name, course_info, created_at)
- **主键**：ID
- **外键**：user_id → Users(ID) [ON DELETE CASCADE]
- **约束**：(user_id, course_id)唯一

```
User_Favorites(ID: INTEGER, user_id: INTEGER, course_id: VARCHAR(255), 
               course_name: VARCHAR(255), course_info: TEXT, created_at: DATETIME)
```

### 4.2 数据完整性约束

#### 4.2.1 实体完整性

- 所有表的主键字段均不允许为空
- 主键值必须唯一

#### 4.2.2 参照完整性

- 外键字段(user_id)必须引用Users表中实际存在的ID值
- 设置ON DELETE CASCADE约束，确保当用户被删除时，相关的课表、聊天记录和收藏也会被自动删除

#### 4.2.3 用户表约束

- email字段设置UNIQUE约束，防止重复注册
- password_hash、full_name字段设置NOT NULL约束

#### 4.2.4 课程信息存储

- 课表中的课程信息以JSON格式存储，便于前端解析和展示
- AI聊天历史中的消息内容以TEXT格式存储，支持长文本内容

### 4.3 关系规范化分析

#### 4.3.1 第一范式(1NF)

所有关系模式中的每个属性都是不可再分的原子值，满足1NF要求。

#### 4.3.2 第二范式(2NF)

所有非主属性完全依赖于主键，不存在部分依赖，满足2NF要求。

#### 4.3.3 第三范式(3NF)

不存在非主属性对主键的传递依赖，满足3NF要求。

## 5. 课程数据处理机制

### 5.1 CSV数据结构

系统从`filtered_courses.csv`文件中加载课程数据，CSV文件包含以下列：

- `新课程序号`：课程的唯一标识符
- `课程名称`：课程的名称
- `排课信息`：包含上课时间、地点、教师等信息的字符串

### 5.2 数据解析机制

系统通过`parse_schedule_string`函数解析排课信息字符串，提取详细的上课时间、地点和教师信息：

```python
def parse_schedule_string(s):
    """
    解析排课字符串，提取详细的上课时间地点信息
    """
    if not s or s.strip() == '':
        return []

    # 使用星期几作为分隔符
    parts = re.split(r'(星期[一二三四五六日])', s)
    entries = []
    
    # 第一段通常是第一个老师的名字（如果有）
    current_name_segment = parts[0]
    
    # 步长为2遍历
    for i in range(1, len(parts), 2):
        day_str = parts[i]
        info_segment = parts[i+1] # 例如 "5-7节 [1-16] 地点 ..."
        
        # 正则匹配: Start-End节 [Weeks] Location
        schedule_match = re.match(r'\s*(\d+)-(\d+)节\s+\[(.*?)\]\s+([^\s]+)', info_segment)
        
        if schedule_match:
            start_node, end_node, week_str, location = schedule_match.groups()
            
            # 尝试提取老师名字
            name_match = re.search(r'([^\s].*?)\((\d+)\)\s*$', current_name_segment)
            teacher_name = "未知"
            if name_match:
                teacher_name = name_match.group(1).strip()
            
            entries.append({
                "day": day_to_int(day_str),
                "day_str": day_str,
                "start": int(start_node),
                "end": int(end_node),
                "weeks": week_str,
                "location": location,
                "teacher": teacher_name
            })
            
            # 更新下一段的前缀，用于查找下一个老师名
            current_name_segment = info_segment[schedule_match.end():]
            
    return entries
```

### 5.3 课程数据结构

解析后的课程数据在内存中以以下结构存储：

```typescript
export interface Session {
  day: number;       // 0-6 (星期一到星期日)
  day_str: string;   // "星期一"到"星期日"
  start: number;     // 1-11 (上课节次)
  end: number;       // 1-11 (上课节次)
  weeks: string;     // 上课周次，如 "1-16周"
  location: string;  // 上课地点
  teacher: string;   // 授课教师
}

export interface Course {
  id: string;        // 课程ID
  name: string;      // 课程名称
  teacher_display: string;  // 显示的教师姓名
  raw_schedule: string;     // 原始排课信息
  sessions: Session[];      // 上课时间地点信息数组
}
```

### 5.4 课程数据加载流程

1. 系统启动时，读取`filtered_courses.csv`文件
2. 将CSV数据转换为DataFrame
3. 遍历每行数据，解析排课信息
4. 将解析后的课程数据存储在全局变量`ALL_COURSES`中
5. 该数据在内存中供前端API调用

## 6. 数据库物理设计

### 6.1 表结构实现

#### 6.1.1 用户表 (users)

```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    avatar_url VARCHAR(500),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

#### 6.1.2 课表表 (timetables)

```sql
CREATE TABLE timetables (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    courses TEXT NOT NULL, -- JSON格式存储课程信息
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

#### 6.1.3 AI聊天历史表 (ai_chat_history)

```sql
CREATE TABLE ai_chat_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    session_id VARCHAR(255) NOT NULL,
    message_role VARCHAR(50) NOT NULL, -- 'user' 或 'assistant'
    message_content TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

#### 6.1.4 用户收藏表 (user_favorites)

```sql
CREATE TABLE user_favorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    course_id VARCHAR(255) NOT NULL,
    course_name VARCHAR(255) NOT NULL,
    course_info TEXT, -- JSON格式存储课程详细信息
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE(user_id, course_id) -- 确保用户对同一课程只能喜欢一次
);
```

### 6.2 索引设计

#### 6.2.1 用户表索引

- 主键索引：id（自动创建）
- 唯一索引：email（自动创建，由于UNIQUE约束）

#### 6.2.2 课表表索引

- 主键索引：id（自动创建）
- 外键索引：user_id（提高关联查询性能）

#### 6.2.3 AI聊天历史表索引

- 主键索引：id（自动创建）
- 外键索引：user_id（提高关联查询性能）
- 复合索引：(user_id, session_id)（提高会话查询性能）

#### 6.2.4 用户收藏表索引

- 主键索引：id（自动创建）
- 外键索引：user_id（提高关联查询性能）
- 唯一复合索引：(user_id, course_id)（自动创建，由于UNIQUE约束）

### 6.3 存储参数设置

#### 6.3.1 数据库引擎选择

使用SQLite作为数据库引擎，具有以下优势：
- 轻量级，无需独立服务器进程
- 事务支持，ACID兼容
- 零配置，易于部署
- 跨平台兼容性好

#### 6.3.2 数据类型选择

- INTEGER：用于ID字段，支持自增主键
- VARCHAR(n)：用于存储变长字符串，n值根据实际需求设定
- TEXT：用于存储较长的文本内容，如课程信息、聊天内容
- DATETIME：用于存储时间戳信息

### 6.4 安全性设计

#### 6.4.1 数据加密

- 密码字段使用哈希算法加密存储，不存储明文密码
- 使用安全的哈希算法（如bcrypt）生成password_hash

#### 6.4.2 访问控制

- 通过外键约束确保数据的关联完整性
- 通过级联删除机制确保用户数据的一致性删除

## 7. 系统功能实现

### 7.1 用户管理功能

系统通过Users表实现用户注册、登录和资料管理功能。用户注册时，系统将用户信息存储到数据库中，密码经过哈希处理后存储。用户登录时，系统验证用户提供的密码与数据库中存储的哈希值是否匹配。

### 7.2 课程管理功能

课程数据主要存储在CSV文件中，通过后端程序加载到内存中进行快速检索。系统支持多维度搜索，包括：

1. **关键字搜索**：基于SQL的LIKE语句进行精确匹配
2. **语义理解搜索**：使用Transformer模型将查询和课程描述转换为向量，计算语义相似度
3. **AI联想搜索**：通过LLM预处理用户查询，提取标准化搜索关键词

### 7.3 课表管理功能

用户创建的课表通过Timetables表进行持久化存储。每个课表包含用户ID、名称、描述和课程信息（以JSON格式存储）。用户可以创建多个课表并随时切换使用。

### 7.4 AI交互功能

AI聊天历史通过AI_Chat_History表进行记录，包括用户问题和AI回答。系统支持多会话管理，通过session_id区分不同会话。AI功能基于RAG技术，结合用户当前课表信息提供个性化推荐。

## 8. 数据库优化策略

### 8.1 查询优化

- 在经常用于查询条件的字段上创建索引
- 使用预编译语句减少SQL解析时间
- 合理设计关联查询，避免笛卡尔积

### 8.2 存储优化

- 使用合适的数据类型，减少存储空间
- 定期清理过期数据，如旧的聊天记录
- 对于大文本字段，考虑压缩存储

### 8.3 性能监控

- 定期检查数据库性能指标
- 监控慢查询日志
- 根据访问模式调整索引策略

## 9. 数据库维护与备份

### 9.1 数据备份策略

- 定期备份整个数据库文件
- 实施增量备份机制
- 将备份文件存储在安全位置

### 9.2 数据恢复机制

- 制定数据恢复流程
- 定期测试备份文件的可用性
- 准备数据恢复工具和脚本

### 9.3 数据迁移方案

- 设计版本兼容的数据迁移脚本
- 确保升级过程中的数据完整性
- 提供回滚机制以防升级失败

## 10. 混合搜索架构设计

### 10.1 搜索策略概述

系统实现了三位一体的混合搜索体验：

1. **L1: 传统关键字搜索 (Keyword Search)**: 利用SQL的LIKE语句或全文索引技术，解决精确匹配需求（如搜索课程代码"CS101"）。

2. **L2: AI 联想关键字检索 (AI Associative Retrieval)**: 针对用户输入的模糊口语（如"适合新手的编程课"），先通过LLM进行预处理，提取出标准化的搜索关键词（如"Introduction", "Programming", "Python"），再进行二次检索，扩大召回范围。

3. **L3: 基于Transformer的向量语义检索 (Vector Semantic Search)**: 使用预训练的Transformer模型将用户查询语句和数据库中的课程描述转换为高维稠密向量，计算相似度并按得分排序。

### 10.2 RAG技术实现

系统采用RAG（检索增强生成）技术，实现以下功能：

- **动态上下文注入**: 在用户提问时，系统实时检索用户的私有数据（当前已选课程、空闲时间槽、历史成绩等）作为Context一并喂给LLM。

- **场景示例**: 用户问"周五下午我能选什么课？"，系统将用户周五下午的空闲时间段数据检索出来注入Prompt，确保AI不会推荐时间冲突的课程。

- **系统提示词工程**: 精心设计的System Prompt规定AI的角色是"专业的教务顾问"，并严格限制其回答必须基于提供的RAG数据，杜绝幻觉。

## 11. 系统架构与技术栈

### 11.1 前端技术栈

- **Vue 3**: 使用Composition API构建响应式逻辑
- **TypeScript**: 强类型约束，确保数据接口的安全性
- **Vite**: 极速构建与热更新
- **UI/UX**: CSS Grid/Flexbox布局，针对聊天流和课表视图的定制化样式

### 11.2 后端技术栈

- **Python Flask**: RESTful API服务及AI逻辑编排
- **SQLite**: 关系型数据存储
- **PyJWT**: 身份验证
- **LangChain / OpenAI API**: 大模型调用与上下文管理
- **Vector Logic**: 基于Transformer的文本向量化处理与相似度计算

### 11.3 数据流处理

1. **数据加载**: 从CSV文件加载课程数据到内存
2. **数据解析**: 解析排课信息字符串为结构化数据
3. **数据存储**: 用户相关数据存储到SQLite数据库
4. **数据检索**: 支持多维度搜索和AI推荐
5. **数据展示**: 前端渲染课程和课表信息

## 12. 总结

本报告详细阐述了课程表管理系统数据库的设计过程，从需求分析到物理实现，全面覆盖了数据库设计的各个阶段。系统通过合理的架构设计，将静态课程数据存储在CSV文件中，用户相关数据存储在SQLite数据库中，实现了高效的数据管理和智能搜索功能。

数据库设计遵循了软件工程的标准规范，确保了数据的完整性、一致性和安全性。同时，考虑到系统的未来发展，设计具有良好的可扩展性，能够适应功能扩展和用户增长的需求。

通过采用SQLite数据库和合理的表结构设计，系统在保证功能完整性的同时，也具有良好的性能表现和部署便利性。结合AI技术和混合搜索架构，系统能够为用户提供智能化的课程推荐和管理服务，满足现代化教学辅助平台的需求。

整体设计充分体现了现代Web应用对数据管理的要求，为系统的稳定运行奠定了坚实基础。