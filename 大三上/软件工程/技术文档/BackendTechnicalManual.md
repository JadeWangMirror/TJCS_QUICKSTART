# Scaffold 后端技术手册

## 目录

1. [项目概述](#项目概述)
2. [技术栈](#技术栈)
3. [项目架构](#项目架构)
4. [目录结构](#目录结构)
5. [核心模块详解](#核心模块详解)
6. [数据库设计](#数据库设计)
7. [API 接口文档](#api-接口文档)
8. [部署指南](#部署指南)
9. [测试指南](#测试指南)

## 项目概述

Scaffold 是一个基于 Flask 的 Web 应用程序，旨在提供一个完整的AI社区平台解决方案。该平台支持用户注册登录、帖子发布与管理、评论互动、点赞收藏、AI辅助功能、搜索推荐等功能。

## 技术栈

| 类别 | 技术 |
|------|------|
| Web框架 | Flask |
| 数据库 | MySQL |
| 缓存 | Redis |
| 异步任务 | Celery |
| API文档 | Flasgger (Swagger) |
| 跨域支持 | Flask-CORS |
| 安全认证 | JWT, bcrypt |
| 邮件服务 | Alibaba Cloud DM |
| AI服务 | DashScope |

## 项目架构

项目采用分层架构模式，遵循 MVC 设计思想：

```
┌─────────────┐
│    API      │ ← 路由和控制器
└─────────────┘
      ↓
┌─────────────┐
│  Services   │ ← 业务逻辑层
└─────────────┘
      ↓
┌─────────────┐
│  Storage    │ ← 数据访问层
└─────────────┘
```

各层职责如下：

### API 层
- 处理 HTTP 请求和响应
- 参数验证和 DTO 转换
- 调用 Service 层处理业务逻辑

### Services 层
- 实现具体的业务逻辑
- 调用 Storage 层进行数据操作
- 调用外部 API 服务

### Storage 层
- 数据库连接和管理
- ORM 模型定义
- 数据持久化操作

### Utils 层
- 工具函数集合
- 日志记录
- 文件处理等通用功能

### Config 层
- 应用配置管理
- 环境变量加载

## 目录结构

```
backend/
├── api/                 # API 层
│   └── routes/          # 路由定义
├── cache/               # 缓存相关
├── middleware/          # 中间件
├── services/            # 业务逻辑层
│   ├── ai_history/      # AI 历史服务
│   ├── api_client/      # 外部 API 客户端
│   ├── auth/            # 认证服务
│   ├── favorite/        # 收藏服务
│   ├── like/            # 点赞服务
│   ├── post/            # 帖子服务
│   └── search/          # 搜索服务
├── storage/             # 数据访问层
├── tests/               # 单元测试
├── utils/               # 工具类
├── config/              # 配置文件
└── app.py              # 应用入口
```

## 核心模块详解

### 1. 认证模块 (Auth)

实现用户注册、登录、登出、密码重置等功能。

#### 主要功能：
- 用户注册与邮箱验证
- JWT Token 认证机制
- 密码加密存储 (bcrypt)
- 用户信息管理

#### 相关文件：
- [auth_routes.py](backend/api/routes/auth_routes.py)
- [UserService.py](backend/services/auth/UserService.py)
- [EmailService.py](backend/services/auth/EmailService.py)

### 2. 帖子模块 (Post)

支持帖子的创建、编辑、删除、浏览等操作。

#### 主要功能：
- 帖子 CRUD 操作
- 评论系统
- 浏览统计
- 帖子推荐算法

#### 相关文件：
- [post_comment_routes.py](backend/api/routes/post_comment_routes.py)
- [Post.py](backend/services/post/Post.py)
- [PostDB.py](backend/storage/PostDB.py)

### 3. 互动模块 (Interaction)

包括点赞、收藏、浏览历史等功能。

#### 主要功能：
- 点赞/取消点赞
- 收藏/取消收藏
- 浏览历史记录
- 互动统计

#### 相关文件：
- [like_routes.py](backend/api/routes/like_routes.py)
- [favorite_routes.py](backend/api/routes/favorite_routes.py)
- [history_routes.py](backend/api/routes/history_routes.py)
- [LikeService.py](backend/services/like/LikeService.py)
- [FavoriteService.py](backend/services/favorite/FavoriteService.py)

### 4. AI 功能模块

提供 AI 提示词优化和图像生成功能。

#### 主要功能：
- Prompt 优化
- AI 图像生成
- 历史记录管理

#### 相关文件：
- [prompt_routes.py](backend/api/routes/prompt_routes.py)
- [image_gen_route.py](backend/api/routes/image_gen_route.py)
- [PromptProcessor.py](backend/services/api_client/PromptProcessor.py)
- [image_gen_deal.py](backend/services/api_client/image_gen_deal.py)

### 5. 搜索模块

支持全文搜索和标签搜索功能。

#### 主要功能：
- 帖子搜索
- 搜索历史管理
- 搜索推荐

#### 相关文件：
- [search_routes.py](backend/api/routes/search_routes.py)
- [SearchService.py](backend/services/search/SearchService.py)
- [SearchDB.py](backend/storage/SearchDB.py)

## 数据库设计

系统使用 MySQL 作为主数据库，通过 SQLAlchemy ORM 进行数据访问。

### 主要数据表：

#### 1. 用户表 (users)
存储用户基本信息和认证数据。

```sql
CREATE TABLE `users` (
    `id` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    `name` VARCHAR(100) NOT NULL COMMENT '用户名',
    `email` VARCHAR(100) NOT NULL COMMENT '邮箱（唯一，必填）',
    `password` VARCHAR(255) NOT NULL COMMENT '哈希加密后的密码',
    `level` INTEGER NOT NULL DEFAULT 1 COMMENT '权限等级',
    `introduce` VARCHAR(500) NULL COMMENT '自我介绍',
    `tag` JSON NULL COMMENT '标签及计数 (map{tag:count})',
    `recommend_tag_list` JSON NULL COMMENT '标签及计数 (map{tag:count})',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`),
    UNIQUE KEY `email` (`email`)
);
```

#### 2. 帖子/评论表 (posts_comments)
存储帖子和评论内容，通过 point_id 实现层级关系。

```sql
CREATE TABLE `posts_comments` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
    `title` VARCHAR(255) NULL COMMENT '帖子标题 (仅主贴使用，评论可空)',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发布时间',
    `context` TEXT NOT NULL COMMENT '内容',
    `author` INTEGER UNSIGNED NOT NULL COMMENT '作者用户ID',
    `url_list` JSON NULL COMMENT '图片/资源 URL 列表 (JSON 列表)',
    `point_id` BIGINT UNSIGNED NULL COMMENT '指向的父帖子/评论ID (用于评论的递归关系)',
    `browse_count` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '浏览数',
    `like_count` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '点赞数',
    `favorite_count` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '收藏数',
    `comment_count` INTEGER UNSIGNED NOT NULL DEFAULT 0 COMMENT '评论数',
    `tag` JSON NULL COMMENT '标签信息 (JSON 格式)',
    PRIMARY KEY (`id`),
    KEY `idx_point_id` (`point_id`)
);
```

#### 3. 点赞表 (likes)
记录用户点赞行为。

```sql
CREATE TABLE `likes` (
    `point_id` BIGINT UNSIGNED NOT NULL COMMENT '被点赞的帖子/评论ID',
    `user_id` INTEGER UNSIGNED NOT NULL COMMENT '点赞人ID',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '点赞时间',
    PRIMARY KEY (`point_id`, `user_id`)
);
```

#### 4. 收藏表 (favorites)
记录用户收藏行为。

```sql
CREATE TABLE `favorites` (
    `point_id` BIGINT UNSIGNED NOT NULL COMMENT '被收藏的帖子/评论ID',
    `user_id` INTEGER UNSIGNED NOT NULL COMMENT '收藏人ID',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '收藏时间',
    PRIMARY KEY (`point_id`, `user_id`)
);
```

#### 5. 浏览历史表 (user_browse_history)
记录用户浏览历史。

```sql
CREATE TABLE `user_browse_history` (
    `id` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '历史记录ID',
    `user_id` INTEGER UNSIGNED NOT NULL COMMENT '用户ID',
    `post_id` BIGINT UNSIGNED NOT NULL COMMENT '被浏览的帖子/评论ID',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '浏览时间',
    PRIMARY KEY (`id`)
);
```

#### 6. AI 历史表 (ai_history)
记录用户使用 AI 功能的历史。

```sql
CREATE TABLE `ai_history` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
    `original_prompt` TEXT NOT NULL COMMENT '用户的原始输入文本',
    `optimized_prompt` TEXT NULL COMMENT '经过优化的 Prompt 文本',
    `workflow_history` JSON NULL COMMENT '工作流历史记录（JSON 格式）',
    `user_id` INTEGER UNSIGNED NOT NULL COMMENT '所属用户ID',
    PRIMARY KEY (`id`),
    KEY `idx_original_prompt_prefix` (`original_prompt`(30)),
    KEY `idx_timestamp` (`timestamp`)
);
```

#### 7. 图片历史表 (image_history)
记录用户生成图片的历史。

```sql
CREATE TABLE `image_history` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
    `prompt` TEXT NOT NULL COMMENT '生成图片的提示词',
    `user_id` INTEGER UNSIGNED NOT NULL COMMENT '所属用户ID',
    `url` TEXT NOT NULL COMMENT '生成的图片URL',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_timestamp` (`timestamp`)
);
```

#### 8. 搜索历史表 (search_history)
记录用户搜索历史。

```sql
CREATE TABLE `search_history` (
    `id` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '搜索历史记录ID',
    `user_id` INTEGER UNSIGNED NOT NULL COMMENT '用户ID',
    `search_query` TEXT NOT NULL COMMENT '搜索关键词',
    `search_type` VARCHAR(20) NOT NULL COMMENT '搜索类型：title, content, tag',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '搜索时间',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_timestamp` (`timestamp`),
    KEY `idx_search_type` (`search_type`)
);
```

#### 9. 用户画像表 (user_profiles)
存储用户兴趣画像。

```sql
CREATE TABLE `user_profiles` (
    `user_id` INTEGER UNSIGNED NOT NULL COMMENT '用户的ID',
    `tag_index` INTEGER UNSIGNED NOT NULL COMMENT '标签的全局索引 (维度)',
    `score` VARCHAR(20) NOT NULL DEFAULT '0.0' COMMENT '用户对该标签的总兴趣分数',
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '兴趣分数最后更新时间',
    PRIMARY KEY (`user_id`, `tag_index`),
    KEY `idx_user_updated` (`user_id`, `last_updated`)
);
```

#### 10. 帖子画像表 (item_profiles)
存储帖子特征画像。

```sql
CREATE TABLE `item_profiles` (
    `post_id` BIGINT UNSIGNED NOT NULL COMMENT '帖子的ID',
    `tag_index` INTEGER UNSIGNED NOT NULL COMMENT '标签的全局索引 (维度)',
    `tag_value` INTEGER NOT NULL DEFAULT 1 COMMENT '标签的权重/值 (基础版为 1)',
    PRIMARY KEY (`post_id`, `tag_index`)
);
```

#### 11. 标签映射表 (global_tag_map)
全局标签索引。

```sql
CREATE TABLE `global_tag_map` (
    `id` INTEGER UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '标签的全局唯一索引 (维度ID)',
    `tag_name` VARCHAR(100) NOT NULL COMMENT '标签名称 (如 Python, AI)',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_tag_name` (`tag_name`)
);
```

## API 接口文档

系统使用 Flasgger 生成 Swagger UI 文档，可以通过 `/apidocs` 路径访问。

### 主要 API 分类：

#### 1. 认证接口
- POST /api/user/send-code - 发送验证码
- POST /api/user/register - 用户注册
- POST /api/user/login - 用户登录
- POST /api/user/logout - 用户登出
- GET /api/user/me - 获取当前用户信息
- POST /api/user/reset-password - 重置密码
- GET /api/user/<int:user_id> - 获取指定用户信息

#### 2. 帖子接口
- GET /api/user/<user_id>/recommend - 推荐帖子
- GET /api/user/hotest - 最热帖子
- GET /api/user/newest - 最新帖子
- GET /api/user/<user_id>/posts - 用户发布的帖子
- POST /api/user/<user_id>/create_post - 创建帖子
- PUT /api/user/<user_id>/<post_id>/update_post - 更新帖子
- DELETE /api/user/<user_id>/<post_id>/delete_post - 删除帖子
- POST /api/user/<user_id>/<post_id>/create_comment - 创建评论
- DELETE /api/user/<user_id>/<comment_id>/delete_comment - 删除评论
- GET /api/user/post/<int:post_id> - 帖子详情

#### 3. 互动接口
- POST /api/user/<int:user_id>/<int:post_id>/like - 点赞/取消点赞
- GET /api/user/<int:user_id>/<int:post_id>/like/status - 获取点赞状态
- POST /api/user/<int:user_id>/<int:post_id>/favorite - 收藏/取消收藏
- GET /api/user/<int:user_id>/<int:post_id>/favorite/status - 获取收藏状态

#### 4. 历史记录接口
- GET /api/user/<int:user_id>/history/ai - AI 历史列表
- GET /api/user/<int:user_id>/history/ai/<int:history_id> - AI 历史详情
- DELETE /api/user/<int:user_id>/history/ai/<int:history_id> - 删除 AI 历史
- DELETE /api/user/<int:user_id>/history/ai - 清空 AI 历史
- GET /api/user/<int:user_id>/history/image - 图片生成历史列表
- GET /api/user/<int:user_id>/history/image/<int:history_id> - 图片生成历史详情
- DELETE /api/user/<int:user_id>/history/image/<int:history_id> - 删除图片生成历史
- DELETE /api/user/<int:user_id>/history/image - 清空图片生成历史
- GET /api/user/<int:user_id>/history/browse - 浏览历史列表
- DELETE /api/user/<int:user_id>/history/browse/<int:record_id> - 删除单条浏览历史
- DELETE /api/user/<int:user_id>/history/browse - 清空浏览历史

#### 5. 搜索接口
- GET /api/user/<int:user_id>/search - 搜索帖子
- GET /api/user/<int:user_id>/history/search - 搜索历史列表
- DELETE /api/user/<int:user_id>/history/search/<int:record_id> - 删除单条搜索历史
- DELETE /api/user/<int:user_id>/history/search - 清空搜索历史

#### 6. AI 接口
- POST /api/optimize - Prompt 优化
- POST /api/generate_image - 图片生成

#### 7. 系统接口
- GET /api/health - 健康检查
- GET /api/statistics - 系统统计信息

## 部署指南

### 环境要求
- Python 3.8+
- MySQL 8.0+
- Redis 6.0+

### 安装步骤

1. 克隆项目代码：
```bash
git clone <项目地址>
cd Scaffold
```

2. 安装依赖：
```bash
pip install -r backend/requirements.txt
```

3. 配置环境变量：
创建以下配置文件：
- backend/config/app_config.json
- backend/config/database.json
- backend/config/redis.json
- backend/config/email.json

4. 初始化数据库：
```bash
python -m backend.storage.init_db
```

5. 启动应用：
```bash
python backend/app.py
```

### 生产环境部署

建议使用以下方式部署生产环境：

1. 使用 Gunicorn 作为 WSGI 服务器：
```bash
gunicorn -w 4 -b 0.0.0.0:5000 backend:app
```

2. 使用 Nginx 作为反向代理：
```nginx
server {
    listen 80;
    server_name your_domain.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

3. 使用 Supervisor 管理进程：
```ini
[program:scaffold]
command=/path/to/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 backend:app
directory=/path/to/Scaffold
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
```

## 测试指南

### 单元测试

项目使用 pytest 进行单元测试。

运行所有测试：
```bash
cd backend
pytest
```

运行特定测试文件：
```bash
pytest tests/test_auth_routes.py
```

### API 测试

可以使用 Swagger UI 或 Postman 进行 API 测试。

1. 启动应用后访问：http://localhost:5000/apidocs
2. 在 Swagger UI 中直接测试各个接口

### 性能测试

建议使用 Apache Bench 或 JMeter 进行性能测试：

```bash
ab -n 1000 -c 100 http://localhost:5000/api/health
```

---

*本文档最后更新于 2025年12月*