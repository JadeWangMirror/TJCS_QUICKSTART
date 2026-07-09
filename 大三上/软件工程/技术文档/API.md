# 前后端接口API文档

**规定** ：

- 我们统一使用Restful API（基于HTTP）
- 下文中所有的URL都基于`baseURL`，此处的`baseURL`代表形如`http://localhost:5000`，`http://127.0.0.1:5000`等截至端口的请求地址

## 用户

### 发送邮箱验证码

**方法**: `POST`

**URL**: `{baseURL}/api/user/send-code`

**功能**: 发送邮箱验证码（用于注册验证）

**Body (JSON 例)**:

```json
{
    "email": "user@example.com"
}
```

**返回**:

```json
{
    "status": "success",
    "message": "验证码已发送，请查收邮件"
}
```

**HTTP 状态码**:
* `200 OK`: 成功发送验证码
* `400 Bad Request`: 邮箱为空
* `429 Too Many Requests`: 发送过于频繁，需要等待冷却时间
* `500 Internal Server Error`: 发送失败

**说明**:
- 验证码有效期为 10 分钟
- 同一邮箱 60 秒内只能发送一次验证码
- 开发环境下验证码会打印在后端日志中

### 用户注册

**方法**: `POST`

**URL**: `{baseURL}/api/user/register`

**功能**: 创建新用户账户（需要邮箱验证码）

**Body (JSON 例)**:

```json
{
    "name": "new_user",
    "email": "user@example.com",
    "verification_code": "123456",
    "password": "secure_password123",
    "introduce": "个人简介",
    "tag": []  
}
```


**返回**:

```json
{
    "status": "success",
    "message": "注册成功",
    "user_id": 1001
}
```


**HTTP 状态码**:
* `201 Created`: 成功注册用户
* `400 Bad Request`: 验证码错误、用户名已存在或参数缺失
* `409 Conflict`: 用户名或邮箱冲突

**说明**:
- 注册前必须先调用发送验证码接口
- 验证码最多可验证 5 次，超过次数需重新发送
- 验证成功后验证码自动失效

### 用户登录

**方法**: `POST`

**URL**: `{baseURL}/api/user/login`

**功能**: 用户身份验证并获取访问令牌

**Body (JSON 例)**:

```json
{
    "name": "existing_user",
    "password": "user_password123"
}
```


**返回**:

```json
{
    "status": "success",
    "message": "登录成功",
    "user_id": 1,
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 3600
}
```


**HTTP 状态码**:
* `200 OK`: 登录成功
* `401 Unauthorized`: 用户名或密码错误
* `400 Bad Request`: 参数缺失

### 重置密码

**方法**: `POST`

**URL**: `{baseURL}/api/user/reset-password`

**功能**: 通过邮箱验证码重置密码（用于忘记密码或修改密码场景）

**Body (JSON 例)**:

```json
{
    "email": "user@example.com",
    "verification_code": "123456",
    "new_password": "new_secure_password123"
}
```

**返回**:

```json
{
    "status": "success",
    "message": "密码重置成功，请使用新密码登录"
}
```

**HTTP 状态码**:
* `200 OK`: 密码重置成功
* `400 Bad Request`: 参数缺失或验证码错误
* `404 Not Found`: 邮箱未注册
* `500 Internal Server Error`: 服务器内部错误

**说明**:
- 重置前必须先调用发送验证码接口获取邮箱验证码
- 新密码长度至少 8 位
- 验证码验证规则与注册相同（10分钟有效期，最多尝试5次）
- 密码重置成功后，用户需使用新密码重新登录

### 获取用户信息

**方法**: `GET`

**URL**: `{baseURL}/api/user/{user_id}`

**功能**: 获取指定用户的公开信息

**返回**:

```json
{
    "status": "success",
    "user": {
        "id": 1,
        "name": "user_name",
        "introduce": "个人简介",
        "tag": ["Python", "Java"],
        "created_at": "2024-10-27T14:30:00"
    }
}
```


### 更新用户信息

**方法**: `PUT`

**URL**: `{baseURL}/api/user/{user_id}`

**功能**: 更新指定用户的信息（需要认证）

**Body (JSON 例)**:

```json
{
    "introduce": "更新的个人简介",
    "tag": ["Python", "JavaScript", "Vue"]
}
```


**返回**:

```json
{
    "status": "success",
    "message": "用户信息更新成功"
}
```


**HTTP 状态码**:
* `200 OK`: 更新成功
* `401 Unauthorized`: 未授权访问
* `403 Forbidden`: 无权限修改他人信息
* `404 Not Found`: 用户不存在

## 资源：帖子 (Posts)

### 获取最新帖子列表 (Newest Posts)

**方法**: `GET`

**URL**: `baseURL/api/user/newest`

**功能**: 获取主帖列表，按发布时间倒序排序。

**参数 (Query Parameters)**:

| 参数 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `limit` | Integer | 10 | 限制返回的帖子数量。 |
| `offset` | Integer | 0 | 用于分页的偏移量。 |

**返回**:

```json
{
    "status": "success",
    "count": 10,
    "limit": 10,
    "offset": 0,
    "posts": [
        {
            "id": 1001,
            "title": "...",
            "context": "...",
            "author": "author_name",
            "timestamp": "2024-10-27T14:30:00",
            "cover_image": "url_to_image",
            "tags": ["Python", "Example"],
            "browse_count": 100,
            "like_count": 20,
            "comment_count": 5
        },
        // ... 更多帖子
    ]
}
```

### 获取最热门帖子列表 (Hottest Posts)

**方法**: `GET`

**URL**: `{baseURL}/api/user/hotest`

**功能**: 获取主帖列表，按浏览数（`browse_count`）降序排序。

**参数 (Query Parameters)**: 与"最新帖子列表"相同。

**返回**: 结构与"最新帖子列表"相同，但 `posts` 数组按浏览数排序。

### 获取个性化推荐列表 (Recommended Posts)

**方法**: `GET`

**URL**: `{baseURL}/api/user/{user_id}/recommend`

**功能**: 根据用户历史兴趣标签（`tag` 计数）进行轮询采样推荐，同时支持全局分页。**此端点内部实现了复杂的缓冲和批量查询优化。**

**参数 (Query Parameters)**:

| 参数 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `limit` | Integer | 10 | 限制返回的帖子数量。 |
| `offset` | Integer | 0 | 用于分页的全局偏移量（跳过已看过的帖子）。 |

**返回**: 结构与"最新帖子列表"相同。

-----

## 资源：新建帖子 (Create Post)

### 创建新帖子

**方法**: `POST`

**URL**: `{baseURL}/api/user/{user_id}/create_post`

**功能**: 以指定 `user_id` 的身份创建一篇新的主贴（`point_id IS NULL`）。

**请求头**: `Content-Type: multipart/form-data`

**Body (表单数据 `form-data` 例)**:

| 字段 | 类型 | 必需 | 说明 |
| :--- | :--- | :--- | :--- |
| `title` | Text | 是 | 帖子的标题。 |
| `context` | Text | 是 | 帖子的主要内容。 |
| `tags` | Text/List | 否 | 标签名，可以重复提交以形成列表（e.g., `tags=Python&tags=DB`）。 |
| `files` | File | 否 | 待上传的图片或资源文件（可多选）。 |

**返回**:

```json
{
    "message": "帖子创建成功",
    "post_id": 20501,
    "image_urls": [
        "http://yourdomain.com/static/uploads/image1.jpg"
    ]
}
```

**HTTP 状态码**:

  * `201 Created`: 成功创建帖子。
  * `400 Bad Request`: 缺少必需的 `title` 或 `context`。
  * `415 Unsupported Media Type`: 请求头 `Content-Type` 不正确。

---


----------------------------------
# TODO
----------------------------------
--------------


## 资源：帖子详情 (Post Detail)

### 查看帖子详情

**方法**: `GET`

**URL**: `{baseURL}/api/user/{user_id}/{post_id}`

**功能**: 获取指定 `post_id` 的帖子详情，包括内容、作者信息、标签、浏览数等。

**返回**:

```json
{
    "status": "success",
    "post": {
        "id": 1001,
        "title": "...",
        "context": "...",
        "author": {
            "id": 1,
            "name": "author_name"
        },
        "timestamp": "2024-10-27T14:30:00",
        "url_list": ["url_to_image"],
        "tags": ["Python", "Example"],
        "browse_count": 100,
        "like_count": 20,
        "comment_count": 5,
        "comments": [
            {
                "id": 2001,
                "context": "...",
                "author": "comment_author_name",
                "timestamp": "2024-10-27T15:00:00",
                "like_count": 5
            }
            // ... 更多评论
        ]
    }
}
```


## 资源：删除帖子 (Delete Post)

### 删除帖子

**方法**: `DELETE`

**URL**: `{baseURL}/api/user/{user_id}/{post_id}/delete_post`

**功能**: 删除指定 `post_id` 的帖子及其所有相关评论。

**返回**:

```json
{
    "message": "帖子删除成功"
}
```


**HTTP 状态码**:

* `200 OK`: 成功删除帖子。
* `404 Not Found`: 指定的帖子不存在。

## 资源：评论 (Comments)

### 创建新评论

**方法**: `POST`

**URL**: `{baseURL}/api/user/{user_id}/{post_id}/create_comment`

**功能**: 以指定 `user_id` 的身份对指定 `post_id` 的帖子或评论创建新评论。

**Body (表单数据 `form-data` 例)**:

| 字段 | 类型 | 必需 | 说明 |
| :--- | :--- | :--- | :--- |
| `context` | Text | 是 | 帖子的主要内容。 |
| `point_id` | INT | 否 | 如果为空则表示对帖子评论，否则是对评论进行回复。 |
| `files` | File | 否 | 待上传的图片或资源文件（可多选）。 |


**返回**:

```json
{
    "message": "评论创建成功",
    "comment_id": 3001,
    "image_urls": [
        "http://yourdomain.com/static/uploads/image1.jpg"
    ]
}
```


**HTTP 状态码**:

* `201 Created`: 成功创建评论。
* `400 Bad Request`: 缺少必需的 `context` 或指定的 `point_id` 不存在。

### 删除评论

**方法**: `DELETE`

**URL**: `{baseURL}/api/user/{user_id}/{comment_id}/delete_comment`

**功能**: 删除指定 `comment_id` 的评论。

**返回**:

```json
{
    "message": "评论删除成功"
}
```


**HTTP 状态码**:

* `200 OK`: 成功删除评论。
* `404 Not Found`: 指定的评论不存在。




### 获取帖子详情

**方法**: `GET`

**URL**: `/api/user/post/<post_id>`

**功能**: 获取指定帖子的详情，包括内容、作者、评论等。同时自动增加帖子浏览数，若用户已登录则记录浏览历史。

**参数说明**:
- `post_id` (路径参数): 帖子ID，必填
- `user_id` (查询参数): 用户ID，可选。若为 None 或 0 表示未登录，不记录历史；若为有效数字则记录历史

**返回 (成功)**:

```json
{
    "status": "success",
    "post": {
        "id": 1001,
        "title": "帖子标题",
        "context": "帖子内容",
        "author": "作者名称",
        "author_id": 123,
        "timestamp": "2024-10-27T14:30:00",
        "url_list": ["http://example.com/image1.jpg"],
        "tags": ["Python", "Django"],
        "browse_count": 101,
        "like_count": 20,
        "comment_count": 5,
        "comments": [
            {
                "id": 2001,
                "context": "评论内容",
                "author": "评论者名称",
                "author_id": 456,
                "timestamp": "2024-10-27T15:00:00",
                "url_list": []
            }
        ]
    }
}
```

**HTTP 状态码**:
- `200 OK`: 成功获取帖子详情
- `404 Not Found`: 帖子不存在
- `400 Bad Request`: 参数类型错误

**副作用**:
- 帖子的 `browse_count` 自动加 1
- 若 `user_id` 为有效的正整数，会在 `user_browse_history` 表中记录一条新的浏览记录

---

### 获取用户浏览历史

**方法**: `GET`

**URL**: `/api/user/<user_id>/history/browse`

**功能**: 获取指定用户的浏览历史记录列表，支持分页

**参数说明**:
- `user_id` (路径参数): 用户ID，必填
- `limit` (查询参数): 单页返回的最大记录数，默认 10，最小 1
- `offset` (查询参数): 分页偏移量，默认 0，最小 0

**返回 (成功)**:

```json
{
    "status": "success",
    "count": 10,
    "total_count": 45,
    "limit": 10,
    "offset": 0,
    "records": [
        {
            "id": 1,
            "post_id": 1001,
            "title": "浏览过的帖子标题",
            "timestamp": "2024-10-28T10:30:00",
            "browse_count": 150,
            "like_count": 25,
            "comment_count": 8
        },
        {
            "id": 2,
            "post_id": 1002,
            "title": "另一篇浏览过的帖子",
            "timestamp": "2024-10-27T14:15:00",
            "browse_count": 120,
            "like_count": 18,
            "comment_count": 5
        }
    ]
}
```

**HTTP 状态码**:
- `200 OK`: 成功获取浏览历史
- `400 Bad Request`: 参数类型或值错误

**说明**:
- 返回的记录按 `timestamp` 降序排列（最新的在前）
- `total_count` 表示该用户的浏览历史总记录数
- `count` 表示本次查询返回的记录数

---

### 删除单条浏览历史记录

**方法**: `DELETE`

**URL**: `/api/user/<user_id>/history/browse/<record_id>`

**功能**: 删除指定用户的某条浏览历史记录。只有记录所有者才能删除

**参数说明**:
- `user_id` (路径参数): 用户ID，必填
- `record_id` (路径参数): 浏览历史记录ID，必填

**返回 (成功)**:

```json
{
    "status": "success",
    "message": "浏览历史删除成功"
}
```

**HTTP 状态码**:
- `200 OK`: 成功删除
- `404 Not Found`: 记录不存在或无权限删除
- `400 Bad Request`: 参数类型错误

**安全性说明**:
- 操作会验证 `user_id` 与记录的所有权，确保用户只能删除自己的历史

---

### 清空用户所有浏览历史

**方法**: `DELETE`

**URL**: `/api/user/<user_id>/history/browse`

**功能**: 清空指定用户的所有浏览历史记录

**参数说明**:
- `user_id` (路径参数): 用户ID，必填

**返回 (成功)**:

```json
{
    "status": "success",
    "message": "浏览历史已清空",
    "deleted_count": 42
}
```

**HTTP 状态码**:
- `200 OK`: 成功清空
- `400 Bad Request`: 参数类型错误

**说明**:
- `deleted_count` 表示删除的记录总数
- 此操作不可逆，建议前端提示用户确认

## 资源：点赞 (Like)

### 切换点赞状态

**方法**: `POST`

**URL**: `{baseURL}/api/user/{user_id}/{post_id}/like`

**功能**: 切换点赞状态。如果用户已点赞则取消点赞，否则执行点赞。一次点赞有效，再点一次取消点赞。

**Body**: 无需请求体

**返回 (点赞成功)**:

```json
{
    "status": "success",
    "message": "点赞成功",
    "post_id": 1001,
    "is_liked": true,
    "like_count": 21
}
```

**返回 (取消点赞成功)**:

```json
{
    "status": "success",
    "message": "已取消点赞",
    "post_id": 1001,
    "is_liked": false,
    "like_count": 20
}
```

**HTTP 状态码**:

* `200 OK`: 点赞/取消点赞成功
* `400 Bad Request`: 参数缺失或无效
* `500 Internal Server Error`: 服务器内部错误

**说明**:
- 使用同一端点进行点赞和取消点赞
- 返回的 `is_liked` 表示操作后的点赞状态
- 返回的 `like_count` 是该帖子/评论的实时点赞总数

### 查询点赞状态

**方法**: `GET`

**URL**: `{baseURL}/api/user/{user_id}/{post_id}/like/status`

**功能**: 获取当前用户是否已点赞某个帖子/评论。前端根据此状态显示不同的 UI（已点赞/未点赞）。

**参数**: 无

**返回 (已点赞)**:

```json
{
    "status": "success",
    "post_id": 1001,
    "is_liked": true
}
```

**返回 (未点赞)**:

```json
{
    "status": "success",
    "post_id": 1001,
    "is_liked": false
}
```

**HTTP 状态码**:

* `200 OK`: 查询成功
* `400 Bad Request`: 参数缺失
* `500 Internal Server Error`: 服务器内部错误

**说明**:
- 页面加载时调用此接口获取初始的点赞状态
- 用于判断点赞按钮的显示样式

---

## 资源：收藏 (Favorite)

### 切换收藏状态

**方法**: `POST`

**URL**: `{baseURL}/api/user/{user_id}/{post_id}/favorite`

**功能**: 切换收藏状态。如果用户已收藏则取消收藏，否则执行收藏。

**Body**: 无需请求体

**返回 (收藏成功)**:

```json
{
    "status": "success",
    "message": "收藏成功",
    "post_id": 1001,
    "is_favorited": true,
    "favorite_count": 16
}
```

**返回 (取消收藏成功)**:

```json
{
    "status": "success",
    "message": "已取消收藏",
    "post_id": 1001,
    "is_favorited": false,
    "favorite_count": 15
}
```

**HTTP 状态码**:

* `200 OK`: 收藏/取消收藏成功
* `400 Bad Request`: 参数缺失或无效
* `500 Internal Server Error`: 服务器内部错误

**说明**:
- 使用同一端点进行收藏和取消收藏
- 返回的 `is_favorited` 表示操作后的收藏状态
- 返回的 `favorite_count` 是该帖子/评论的实时收藏总数

### 查询收藏状态

**方法**: `GET`

**URL**: `{baseURL}/api/user/{user_id}/{post_id}/favorite/status`

**功能**: 获取当前用户是否已收藏某个帖子/评论。前端根据此状态显示不同的 UI（已收藏/未收藏）。

**参数**: 无

**返回 (已收藏)**:

```json
{
    "status": "success",
    "post_id": 1001,
    "is_favorited": true
}
```

**返回 (未收藏)**:

```json
{
    "status": "success",
    "post_id": 1001,
    "is_favorited": false
}
```

**HTTP 状态码**:

* `200 OK`: 查询成功
* `400 Bad Request`: 参数缺失
* `500 Internal Server Error`: 服务器内部错误

**说明**:
- 页面加载时调用此接口获取初始的收藏状态
- 用于判断收藏按钮的显示样式

---

## 资源：AI历史记录 (AI History)

### 获取AI历史记录列表

**方法**: `GET`

**URL**: `{baseURL}/api/history`

**功能**: 获取AI历史记录列表。

**参数 (Query Parameters)**:

| 参数 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `limit` | Integer | 10 | 限制返回的记录数量。 |
| `offset` | Integer | 0 | 用于分页的偏移量。 |

**返回**:

```json
{
    "status": "success",
    "count": 10,
    "limit": 10,
    "offset": 0,
    "records": [
        {
            "id": 1,
            "timestamp": "2024-10-27T14:30:00",
            "original_prompt": "用户的原始输入文本",
            "optimized_prompt": "经过优化的 Prompt 文本"
        }
        // ... 更多记录
    ]
}
```


### 获取AI历史记录详情

**方法**: `GET`

**URL**: `{baseURL}/api/history/{record_id}`

**功能**: 获取指定 `record_id` 的AI历史记录详情。

**返回**:

```json
{
    "status": "success",
    "record": {
        "id": 1,
        "timestamp": "2024-10-27T14:30:00",
        "original_prompt": "用户的原始输入文本",
        "optimized_prompt": "经过优化的 Prompt 文本",
        "workflow_history": {}  // 工作流历史记录（JSON 格式）
    }
}
```


## 资源：Prompt优化 (Prompt Optimization)

### 优化Prompt

**方法**: `POST`

**URL**: `{baseURL}/api/optimize`

**功能**: 对用户输入的prompt进行优化。

**Body (JSON 例)**:

```json
{
    "prompt": "需要优化的原始prompt"
}
```


**返回**:

```json
{
    "status": "success",
    "optimized_prompt": "优化后的prompt"
}
```


## 资源：系统接口 (System APIs)

### 健康检查

**方法**: `GET`

**URL**: `{baseURL}/api/health`

**功能**: 检查系统健康状态。

**返回**:

```json
{
    "status": "healthy"
}
```


### 系统统计信息

**方法**: `GET`

**URL**: `{baseURL}/api/statistics`

**功能**: 获取系统统计信息。

**返回**:

```json
{
    "status": "success",
    "total_users": 100,
    "total_posts": 1000,
    "total_comments": 5000
}
```
