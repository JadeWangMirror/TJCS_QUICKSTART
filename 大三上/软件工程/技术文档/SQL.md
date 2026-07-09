# 数据库文档

## 概述

本项目使用 MySQL 数据库，采用 InnoDB 引擎，字符集为 utf8mb4。数据库设计支持用户管理、帖子评论系统、点赞功能、浏览历史以及 AI 辅助功能。

## 统一数据库入口

1. 首先在命令行连接MySQL服务：

```bash
  mysql -u root -p
```

2. 输入密码进入MySQL后，运行：

```sql
  create user 'scaffold'@'localhost' identified by 'scaffold'; 
  create database ccb;
  grant all on ccb.* to 'scaffold'@'localhost';
```

进行用户设置与授权（安全考虑，非常不建议使用root）

3.退出MySQL后，切换到新用户：

```bash
  mysql -u scaffold -p
```

输入密码进入后：

```sql
  use ccb;
  source backend/storage/db.sql;
```  

使用 source 命令运行数据库文件，创建表单

**⚠️ 重要提示**：

- **推荐方式**：使用 `python -m backend.storage.init_db` 通过 SQLAlchemy ORM 自动创建表结构
- **手动方式**：如果需要手动运行 SQL 文件，使用上述 `source` 命令
- `backend/storage/models.py` 是数据库表结构的**权威定义**

## 文件说明

```bash
backend/storage/
├── models.py           # SQLAlchemy ORM 模型定义（权威定义）
├── db.sql              # 完整的数据库结构（根据 models.py 生成）
├── init_db.py          # 数据库初始化脚本
└── __init__.py         # 存储模块初始化
```

## 数据库表结构

### 1. users - 用户表

存储用户基本信息和权限。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT UNSIGNED | 用户ID（主键，自增） |
| name | VARCHAR(100) | 用户名（唯一） |
| email | VARCHAR(100) | 邮箱（唯一，必填） |
| password | VARCHAR(255) | 哈希加密后的密码 |
| level | INT | 权限等级（默认1） |
| introduce | VARCHAR(500) | 自我介绍 |
| tag | JSON | 标签及计数 |
| recommend_tag_list | JSON | 标签及计数
| created_at | TIMESTAMP | 创建时间 |

### 2. posts_comments - 帖子/评论表

统一存储帖子和评论，通过 `point_id` 实现评论的递归关系。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | ID（主键，自增） |
| title | VARCHAR(255) | 帖子标题（评论可空） |
| timestamp | TIMESTAMP | 发布时间 |
| context | TEXT | 内容 |
| author | INT UNSIGNED | 作者用户ID（外键） |
| url_list | JSON | 图片/资源URL列表 |
| point_id | BIGINT UNSIGNED | 父帖子/评论ID（评论用） |
| browse_count | BIGINT UNSIGNED | 浏览数 |
| like_count | BIGINT UNSIGNED | 点赞数 |
| comment_count | INT UNSIGNED | 评论数 |
| tag | JSON | 标签信息 |

### 3. likes - 点赞表

记录用户的点赞行为。

| 字段 | 类型 | 说明 |
|------|------|------|
| point_id | BIGINT UNSIGNED | 被点赞的帖子/评论ID |
| user_id | INT UNSIGNED | 点赞人ID |
| timestamp | TIMESTAMP | 点赞时间 |

**联合主键**: (point_id, user_id) - 保证一个用户对同一内容只能点赞一次

### 4. user_browse_history - 浏览历史表

记录用户的浏览行为。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INT UNSIGNED | 历史记录ID（主键，自增） |
| user_id | INT UNSIGNED | 用户ID |
| post_id | BIGINT UNSIGNED | 被浏览的帖子ID |
| timestamp | TIMESTAMP | 浏览时间 |

### 5. ai_history - AI 历史记录表

存储用户使用 AI 功能的历史记录。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键ID（自增） |
| timestamp | TIMESTAMP | 记录时间 |
| original_prompt | TEXT | 用户的原始输入 |
| optimized_prompt | TEXT | 优化后的 Prompt |
| workflow_history | JSON | 工作流历史记录 |
| user_id | INT UNSIGNED | 所属用户ID（外键） |

### 6. image_history - 图片生成历史记录表

存储用户使用 AI 生成图片的历史记录。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT UNSIGNED | 主键ID（自增） |
| timestamp | TIMESTAMP | 记录时间 |
| prompt | TEXT | 生成图片的提示词 |
| user_id | INT UNSIGNED | 所属用户ID（外键） |
| url | TEXT | 生成的图片URL |

## 外键关系

### 级联删除策略（ON DELETE CASCADE）

**用户注销时的级联删除**：

- 删除用户时，会自动删除：
  - 该用户发布的所有帖子和评论（posts_comments 表）
  - 该用户的所有点赞记录（likes 表）
  - 该用户的所有浏览历史（user_browse_history 表）
  - 该用户的所有 AI 历史记录（ai_history 表）
  - 该用户的所有图片生成历史（image_history 表）

**帖子/评论删除时的级联删除**：

- 删除帖子时，会自动删除：
  - 该帖子下的所有评论（递归删除）
  - 该帖子的所有点赞记录
  - 该帖子的所有浏览记录

## 注意事项

1. **密码安全**: 用户密码必须经过哈希加密后再存储，建议使用 bcrypt 或 Argon2 算法
2. **JSON 字段**: `tag`、`url_list`、`workflow_history` 等字段使用 JSON 格式，方便存储复杂数据结构
3. **索引优化**: 已在常用查询字段上创建索引，提高查询性能
4. **字符集**: 使用 utf8mb4 支持完整的 Unicode 字符（包括 emoji）
5. **存储引擎**: 使用 InnoDB 引擎，支持事务和外键约束

## 后端配置

在后端的 `storage` 层需要配置数据库连接信息，请参考配置文件 `backend/config/db.json` 。

## 维护说明

- **数据库版本**: MySQL 5.7+
- **备份建议**: 定期使用 `mysqldump` 进行数据库备份
- **监控建议**: 监控表的大小和索引效率，必要时进行优化

## 数据库迁移

如果需要修改表结构，请：
1. 创建新的迁移 SQL 文件
2. 在文件中记录修改内容和时间