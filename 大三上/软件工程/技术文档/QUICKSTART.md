# 🚀 快速启动指南 - 用户认证功能

## 📋 前置要求

- Python 3.8+
- Node.js 20.19.0+ 或 22.12.0+
- MySQL 5.7+
- pnpm

## ⚡ 5 分钟快速部署

### 步骤 1: 克隆项目（如果还没有）

```bash
git clone <your-repo-url>
cd Scaffold
```

### 步骤 2: 配置数据库

```bash
# 连接 MySQL
mysql -u root -p

# 在 MySQL 中执行
CREATE USER 'scaffold'@'localhost' IDENTIFIED BY 'scaffold';
CREATE DATABASE ccb;
GRANT ALL ON ccb.* TO 'scaffold'@'localhost';
EXIT;
```

### 步骤 3：配置Redis服务端

```bash
# 以下操作需要在Linux下进行，推荐wsl
# 更新软件包列表
sudo apt update

# 安装 Redis Server
sudo apt install redis-server

# 使用 nano 编辑器配置密码
sudo nano /etc/redis/redis.conf

# 找到这行 (可能在前面有 #)
# requirepass foobared

# 修改为scaffold，并确保前面没有 #
requirepass scaffold

# 保存并退出

# 启动 Redis 服务
sudo systemctl start redis-server
```

使用以下方法验证Redis服务端配置是否生效：

```bash
redis-cli
PING
# 预期返回：(error) NOAUTH Authentication required.
AUTH scaffold
# 预期返回：OK
PING
# 预期返回：PONG
```

### 步骤 4: 安装后端依赖

```bash
cd backend
pip install -r requirements.txt
```

**确认已安装的关键依赖**:

- Flask==2.3.3
- SQLAlchemy==2.0.23
- PyMySQL==1.1.0
- redis==7.0.1
- celery==5.5.3
- bcrypt==4.1.2 ⭐ 密码加密
- PyJWT==2.8.0 ⭐ Token 生成

### 步骤 5: 初始化数据库

```bash
# 使用 ORM 初始化（推荐）
python -m backend.storage.init_db

# 或者手动执行 SQL
mysql -u scaffold -p ccb < database/db.sql
```

### 步骤 6：启动celery（每次启动都需要）
两个终端

```bash
celery -A backend.cache.cache:celery_app worker -l info -P solo
```
```bach
celery -A backend.cache.cache:celery_app beat -l info
```

### 步骤 7: 启动后端服务

```bash
python -m backend.app
```

✅ 后端服务运行在: **http://localhost:5000**

### 步骤 8: 安装前端依赖

```bash
# 打开新终端
cd frontend
pnpm install
```

### 步骤 9: 配置前端环境变量

创建 `frontend/.env.development`:

```env
VITE_API_BASE_URL=http://localhost:5000
```

或者在 `frontend/.env` 中设置（如果文件不存在则创建）。

### 步骤 10: 启动前端服务

```bash
pnpm dev
```

✅ 前端服务运行在: **http://localhost:5173**

---

## 🧪 测试认证功能

### 方式 1: 浏览器测试

1. 打开浏览器访问: **http://localhost:5173/auth/register**
2. 填写注册表单:
   - 邮箱: `test@example.com`
   - 昵称: `测试用户`
   - 密码: `password123`
   - 确认密码: `password123`
3. 点击"注册并继续"
4. 注册成功后自动跳转到登录页
5. 使用刚才的邮箱和密码登录
6. 登录成功后跳转到首页

### 方式 2: API 测试脚本

```bash
cd backend
python test_auth_api.py
```

### 方式 3: curl 测试

```bash
# 注册
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "nickname": "测试用户"
  }'

# 登录
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

---

## 📂 关键文件位置

### 后端核心文件

```
backend/
├── services/auth/UserService.py      # 用户服务（业务逻辑）
├── api/routes/auth_routes.py         # 认证路由（API 接口）
├── storage/models.py                 # 数据库模型
├── config/db.json                    # 数据库配置
└── test_auth_api.py                  # 测试脚本
```

### 前端核心文件

```
frontend/src/
├── views/auth/LoginView.vue          # 登录页面
├── views/auth/RegisterView.vue       # 注册页面
├── services/auth.service.ts          # 认证服务
├── services/http.ts                  # HTTP 客户端
└── store/modules/auth.ts             # 状态管理
```

### 文档

```
doc/
├── AUTH.md                           # 详细实现文档
├── AUTH_COMPATIBILITY.md             # 兼容性检查
├── API.md                            # API 接口文档
└── SQL.md                            # 数据库文档
```

---

## 🔍 功能验证清单

### 注册功能

- [ ] 可以使用邮箱注册
- [ ] 密码少于 8 位时显示错误
- [ ] 两次密码不一致时显示错误
- [ ] 邮箱已存在时显示错误
- [ ] 注册成功后跳转到登录页

### 登录功能

- [ ] 可以使用邮箱和密码登录
- [ ] 邮箱不存在时显示错误
- [ ] 密码错误时显示错误
- [ ] 登录成功后跳转到首页
- [ ] Token 保存在 localStorage

### Token 管理

- [ ] 刷新页面后登录状态保持
- [ ] Token 自动添加到请求头
- [ ] Token 过期后自动跳转登录页

---

## 🐛 常见问题排查

### 问题 1: 后端启动失败

**错误**: `ModuleNotFoundError: No module named 'bcrypt'`

**解决**:

```bash
pip install bcrypt PyJWT
```

### 问题 2: 数据库连接失败

**错误**: `Access denied for user 'scaffold'@'localhost'`

**解决**:

```bash
# 重新设置数据库权限
mysql -u root -p
> GRANT ALL ON ccb.* TO 'scaffold'@'localhost';
> FLUSH PRIVILEGES;
```

### 问题 3: 前端 CORS 错误

**错误**: `Access to XMLHttpRequest has been blocked by CORS policy`

**解决**:

- 确认后端已安装 Flask-CORS: `pip install Flask-CORS`
- 检查 `backend/app.py` 中是否有 `CORS(app)`

### 问题 4: 前端无法连接后端

**错误**: `Network Error` 或 `ERR_CONNECTION_REFUSED`

**解决**:

1. 确认后端服务是否运行在 5000 端口
2. 检查 `.env` 文件中的 `VITE_API_BASE_URL`
3. 确认防火墙没有阻止端口

### 问题 5: 注册后提示邮箱已存在

**解决**:

```bash
# 清空测试数据
mysql -u scaffold -p ccb
> DELETE FROM users WHERE name = 'test@example.com';
```

---

## 📊 数据库查看

```bash
# 连接数据库
mysql -u scaffold -p ccb

# 查看所有用户
SELECT id, name, level, created_at FROM users;

# 查看特定用户
SELECT * FROM users WHERE name = 'test@example.com';

# 查看密码哈希（已加密）
SELECT id, name, password FROM users;
```

---

## 🎯 下一步

认证功能测试通过后，可以继续开发:

1. **帖子管理**: 创建、编辑、删除帖子
2. **评论功能**: 评论、回复
3. **点赞功能**: 点赞帖子和评论
4. **AI 工作台**: Prompt 优化
5. **推荐系统**: 个性化推荐

所有这些功能都可以使用当前的认证系统来识别用户身份！

---

## 📞 获取帮助

- 查看详细文档: `doc/AUTH.md`
- 查看 API 文档: `doc/API.md`
- 运行测试脚本: `python backend/test_auth_api.py`
- 检查前后端兼容性: `doc/AUTH_COMPATIBILITY.md`

---

## ✅ 部署检查清单

启动服务前确认:

- [X] MySQL 服务运行中
- [X] 数据库 `ccb` 已创建
- [X] 用户 `scaffold` 已授权
- [X] 数据库表已初始化（`users` 表存在）
- [X] Python 依赖已安装（包括 bcrypt, PyJWT）
- [X] Node.js 依赖已安装
- [X] 环境变量已配置
- [X] 后端运行在 5000 端口
- [X] 前端运行在 5173 端口

**🎉 全部完成后，你的用户认证系统就可以使用了！**
