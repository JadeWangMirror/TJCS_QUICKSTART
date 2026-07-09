import pandas as pd
from flask import Flask, jsonify, request
from flask_cors import CORS
import re
import os
import requests
import json
# 在文件最顶部 import 区域加入这两行
from sentence_transformers import SentenceTransformer, util
import torch
import sqlite3
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
import datetime

app = Flask(__name__)
# 允许前端跨域访问
CORS(app)

# ================= 配置区域 =================
# ⚠️ 请务必使用你的真实 API Key
AI_API_KEY = "sk-bd74438cf81d4f4c94fbf7fbb61a023e" 
# DeepSeek 官方 API 地址
AI_API_URL = "https://api.deepseek.com/v1/chat/completions" 
SECRET_KEY = "your-secret-key-change-this-in-production"
# ===========================================

# --- 数据库初始化 ---
def init_db():
    conn = sqlite3.connect('timetable.db')
    cursor = conn.cursor()
    
    # 创建用户表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email VARCHAR(255) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            full_name VARCHAR(255) NOT NULL,
            avatar_url VARCHAR(500),
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # 创建课表表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS timetables (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name VARCHAR(255) NOT NULL,
            description TEXT,
            courses TEXT NOT NULL, -- JSON格式存储课程信息
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    ''')
    
    # 创建AI聊天历史记录表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS ai_chat_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            session_id VARCHAR(255) NOT NULL,
            message_role VARCHAR(50) NOT NULL, -- 'user' 或 'assistant'
            message_content TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    ''')
    
    # 创建用户喜欢课程表
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            course_id VARCHAR(255) NOT NULL,
            course_name VARCHAR(255) NOT NULL,
            course_info TEXT, -- JSON格式存储课程详细信息
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE(user_id, course_id) -- 确保用户对同一课程只能喜欢一次
        )
    ''')
    
    conn.commit()
    conn.close()

# --- 1. 数据解析逻辑 ---

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

def day_to_int(day_str):
    mapping = {
        '星期一': 0, '星期二': 1, '星期三': 2, '星期四': 3, 
        '星期五': 4, '星期六': 5, '星期日': 6
    }
    # 直接返回0-based索引
    return mapping.get(day_str, 0)  # 默认为0（星期一）

def load_and_parse_data():
    """读取 CSV 并解析为内存对象"""
    csv_path = os.path.join(os.path.dirname(__file__), 'filtered_courses.csv')
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        return []

    print("正在加载课程数据...")
    df = pd.read_csv(csv_path)
    df = df.fillna('')
    
    parsed_courses = []

    for _, row in df.iterrows():
        # 确保转为字符串
        course_id = str(row.get('新课程序号', ''))
        course_name = str(row.get('课程名称', ''))
        schedule_str = str(row.get('排课信息', ''))
        
        sessions = parse_schedule_string(schedule_str)
        
        # 只有解析出时间的课程才被视为有效（或者你可以选择保留所有）
        parsed_courses.append({
            "id": course_id,
            "name": course_name,
            "sessions": sessions,
            "raw_schedule": schedule_str,
            "teacher_display": sessions[0]['teacher'] if sessions else "未知"
        })
        
    print(f"成功加载 {len(parsed_courses)} 门课程")
    return parsed_courses

# 全局变量：内存中的课程数据
ALL_COURSES = load_and_parse_data()

# --- 2. 路由接口 ---

@app.route('/api/courses', methods=['GET'])
def get_courses():
    """获取所有课程"""
    return jsonify(ALL_COURSES)

@app.route('/api/ai-search', methods=['POST'])
def ai_search():
    """
    终极修复版：独立数据源模式
    强制重新读取 CSV，防止全局变量被污染导致的"搜索锁定"
    """
    data = request.get_json()
    user_query = data.get('query', '')

    if not user_query:
        # 如果没有搜索词，尝试返回全局数据，如果全局数据被污染也无所谓，只要不崩就行
        return jsonify(ALL_COURSES[:50])

    print(f"收到 AI 搜索请求: {user_query}")

    # --- 1. 懒加载模型与建立索引 ---
    if not hasattr(app, 'vector_engine'):
        print("⚡️ 检测到首次搜索，正在从源文件构建独立索引...")
        try:
            # 【核心修复】：不要使用 ALL_COURSES，而是现场重新加载最干净的数据
            # 调用你上面定义的 load_and_parse_data 函数
            # 这样即使 ALL_COURSES 在别处被删改了，这里的 clean_data 也是完整的
            clean_data = load_and_parse_data() 
            
            # 如果重新加载失败（比如文件被占用了），那没办法只能用全局的做保底
            if not clean_data:
                print("⚠️ 重新加载数据失败，回退使用内存数据")
                clean_data = list(ALL_COURSES)

            model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
            
            # 准备语料
            corpus_texts = [f"{c['name']} {c['teacher_display']}" for c in clean_data]
            
            print(f"正在为 {len(corpus_texts)} 门课程生成向量...")
            course_embeddings = model.encode(corpus_texts, convert_to_tensor=True)
            
            # 挂载到 app，包含这份独立的干净数据
            app.vector_engine = {
                'model': model,
                'embeddings': course_embeddings,
                'clean_data': clean_data # <--- 搜索时只用这份私有的数据
            }
            print("✅ 独立向量索引构建完成！")
            
        except Exception as e:
            print(f"❌ 初始化失败: {e}")
            return jsonify({"error": str(e)}), 500

    # --- 2. 执行向量搜索 ---
    engine = app.vector_engine
    model = engine['model']
    corpus_embeddings = engine['embeddings']
    # 从私有数据源取数据
    stored_courses = engine['clean_data']

    # 编码查询
    query_embedding = model.encode(user_query, convert_to_tensor=True)
    
    # 计算相似度
    cos_scores = util.cos_sim(query_embedding, corpus_embeddings)[0]

    # 取 Top 10
    # 确保 k 不会超过数据总量
    top_k = min(10, len(stored_courses))
    top_results = torch.topk(cos_scores, k=top_k)

    response_data = []
    for score, idx in zip(top_results.values, top_results.indices):
        idx = int(idx)
        score = float(score)

        # 从干净的私有数据中取值
        course_data = stored_courses[idx].copy()
        
        # 调试用：打印一下排在第一位的是谁，看看是不是你要的
        # if len(response_data) == 0:
        #     print(f"Top 1 match: {course_data['name']} (Score: {score})")

        course_data['match_score'] = f"{score:.2f}" 
        response_data.append(course_data)

    print(f"搜索完成，返回 {len(response_data)} 条结果")
    return jsonify(response_data)

# --- 3. 用户认证相关接口 ---

@app.route('/api/register', methods=['POST'])
def register():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    full_name = data.get('full_name')
    avatar_url = data.get('avatar_url', '')

    if not email or not password or not full_name:
        return jsonify({'error': '缺少必需字段'}), 400

    conn = sqlite3.connect('timetable.db')
    cursor = conn.cursor()

    try:
        # 检查邮箱是否已存在
        cursor.execute('SELECT id FROM users WHERE email = ?', (email,))
        if cursor.fetchone():
            return jsonify({'error': '邮箱已被注册'}), 400

        # 创建新用户
        hashed_password = generate_password_hash(password)
        cursor.execute('''
            INSERT INTO users (email, password_hash, full_name, avatar_url)
            VALUES (?, ?, ?, ?)
        ''', (email, hashed_password, full_name, avatar_url))

        user_id = cursor.lastrowid
        conn.commit()

        # 生成JWT token
        token = jwt.encode({
            'user_id': user_id,
            'email': email,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(days=30)
        }, SECRET_KEY, algorithm='HS256')

        # 返回用户信息，注意字段名要与登录接口一致
        return jsonify({
            'token': token,
            'user': {
                'id': user_id,
                'email': email,
                'full_name': full_name,
                'avatar_url': avatar_url
            }
        }), 201

    except sqlite3.Error as e:
        return jsonify({'error': f'数据库错误: {str(e)}'}), 500
    except Exception as e:
        return jsonify({'error': f'注册失败: {str(e)}'}), 500
    finally:
        conn.close()

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')

    if not email or not password:
        return jsonify({'error': '邮箱和密码是必需的'}), 400

    conn = sqlite3.connect('timetable.db')
    cursor = conn.cursor()

    try:
        # 查找用户
        cursor.execute('SELECT id, email, password_hash, full_name, avatar_url FROM users WHERE email = ?', (email,))
        user = cursor.fetchone()

        if not user or not check_password_hash(user[2], password):  # password_hash是第3列
            return jsonify({'error': '邮箱或密码错误'}), 401

        # 生成JWT token
        token = jwt.encode({
            'user_id': user[0],  # id是第1列
            'email': user[1],    # email是第2列
            'exp': datetime.datetime.utcnow() + datetime.timedelta(days=30)
        }, SECRET_KEY, algorithm='HS256')

        return jsonify({
            'token': token,
            'user': {
                'id': user[0],
                'email': user[1],
                'full_name': user[3],      # full_name是第4列
                'avatar_url': user[4]      # avatar_url是第5列
            }
        }), 200

    except sqlite3.Error as e:
        return jsonify({'error': f'数据库错误: {str(e)}'}), 500
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401
    except Exception as e:
        return jsonify({'error': f'登录失败: {str(e)}'}), 500
    finally:
        conn.close()

# --- 4. 课表管理接口 ---

@app.route('/api/timetables', methods=['GET'])
def get_timetables():
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'error': '未提供认证token'}), 401

    try:
        payload = jwt.decode(token.replace('Bearer ', ''), SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    conn = sqlite3.connect('timetable.db')
    cursor = conn.cursor()

    try:
        cursor.execute('''
            SELECT t.id, t.name, t.description, t.courses, t.created_at
            FROM timetables t
            WHERE t.user_id = ?
            ORDER BY t.created_at DESC
        ''', (user_id,))
        timetables = cursor.fetchall()

        result = []
        for tbl in timetables:
            result.append({
                'id': tbl[0],
                'name': tbl[1],
                'description': tbl[2],
                'courses': json.loads(tbl[3]),  # 解析JSON字符串
                'created_at': tbl[4]
            })

        return jsonify(result), 200

    except sqlite3.Error as e:
        return jsonify({'error': f'数据库错误: {str(e)}'}), 500
    except Exception as e:
        return jsonify({'error': f'获取课表失败: {str(e)}'}), 500
    finally:
        conn.close()

@app.route('/api/save_timetable', methods=['POST'])
def save_timetable():
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    data = request.get_json()
    name = data.get('name')
    remark = data.get('remark', '')  # 使用description字段存储备注
    courses = data.get('courses', [])

    if not name:
        return jsonify({'error': '课表名称不能为空'}), 400

    try:
        conn = sqlite3.connect('timetable.db')
        c = conn.cursor()
        
        # 检查是否已存在同名课表
        c.execute("SELECT id FROM timetables WHERE user_id = ? AND name = ?", (user_id, name))
        existing = c.fetchone()
        if existing:
            # 更新已存在的课表
            c.execute("""
                UPDATE timetables 
                SET courses = ?, description = ?, updated_at = CURRENT_TIMESTAMP 
                WHERE user_id = ? AND name = ?
            """, (json.dumps(courses), remark, user_id, name))
        else:
            # 插入新课表
            c.execute("""
                INSERT INTO timetables (user_id, name, description, courses) 
                VALUES (?, ?, ?, ?)
            """, (user_id, name, remark, json.dumps(courses)))
        
        conn.commit()
        conn.close()
        return jsonify({'message': '课表保存成功'}), 200
    except Exception as e:
        print(f"保存课表时出错: {str(e)}")  # 添加调试信息
        return jsonify({'error': str(e)}), 500

@app.route('/api/saved_timetables', methods=['GET'])
def get_saved_timetables():
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    try:
        conn = sqlite3.connect('timetable.db')
        c = conn.cursor()
        c.execute("""
            SELECT id, name, description, courses, created_at
            FROM timetables 
            WHERE user_id = ?
            ORDER BY created_at DESC
        """, (user_id,))
        
        rows = c.fetchall()
        timetables = []
        for row in rows:
            timetables.append({
                'id': row[0],
                'name': row[1],
                'remark': row[2],  # 使用remark字段名与前端保持一致
                'courses': row[3],
                'created_at': row[4]
            })
        
        conn.close()
        return jsonify(timetables), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/saved_timetables/<int:timetable_id>', methods=['DELETE'])
def delete_saved_timetable(timetable_id):
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    try:
        conn = sqlite3.connect('timetable.db')
        c = conn.cursor()
        c.execute("DELETE FROM timetables WHERE id = ? AND user_id = ?", (timetable_id, user_id))
        
        if c.rowcount == 0:
            conn.close()
            return jsonify({'error': '课表不存在或无权限删除'}), 404
        
        conn.commit()
        conn.close()
        return jsonify({'message': '课表删除成功'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/timetables/<int:timetable_id>', methods=['GET'])
def get_timetable(timetable_id):
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'error': '未提供认证token'}), 401

    try:
        payload = jwt.decode(token.replace('Bearer ', ''), SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    conn = sqlite3.connect('timetable.db')
    cursor = conn.cursor()

    try:
        cursor.execute('''
            SELECT t.id, t.name, t.description, t.courses, t.created_at
            FROM timetables t
            WHERE t.id = ? AND t.user_id = ?
        ''', (timetable_id, user_id))
        result = cursor.fetchone()

        if not result:
            return jsonify({'error': '未找到课表或无权访问'}), 404

        return jsonify({
            'id': result[0],
            'name': result[1],
            'description': result[2],
            'courses': json.loads(result[3]),
            'created_at': result[4]
        }), 200

    except sqlite3.Error as e:
        return jsonify({'error': f'数据库错误: {str(e)}'}), 500
    except Exception as e:
        return jsonify({'error': f'获取课表失败: {str(e)}'}), 500
    finally:
        conn.close()

@app.route('/api/timetables/<int:timetable_id>', methods=['PUT'])
def update_timetable(timetable_id):
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'error': '未提供认证token'}), 401

    try:
        payload = jwt.decode(token.replace('Bearer ', ''), SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    data = request.get_json()
    name = data.get('name')
    description = data.get('description', '')
    courses = data.get('courses', [])

    if not name:
        return jsonify({'error': '缺少课表名称'}), 400

    conn = sqlite3.connect('timetable.db')
    cursor = conn.cursor()

    try:
        cursor.execute('''
            UPDATE timetables
            SET name = ?, description = ?, courses = ?
            WHERE id = ? AND user_id = ?
        ''', (name, description, json.dumps(courses), timetable_id, user_id))

        if cursor.rowcount == 0:
            return jsonify({'error': '未找到课表或无权访问'}), 404

        conn.commit()

        return jsonify({
            'message': '课表更新成功'
        }), 200

    except sqlite3.Error as e:
        return jsonify({'error': f'数据库错误: {str(e)}'}), 500
    except Exception as e:
        return jsonify({'error': f'更新课表失败: {str(e)}'}), 500
    finally:
        conn.close()

@app.route('/api/timetables/<int:timetable_id>', methods=['DELETE'])
def delete_timetable(timetable_id):
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'error': '未提供认证token'}), 401

    try:
        payload = jwt.decode(token.replace('Bearer ', ''), SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    conn = sqlite3.connect('timetable.db')
    cursor = conn.cursor()

    try:
        cursor.execute('''
            DELETE FROM timetables
            WHERE id = ? AND user_id = ?
        ''', (timetable_id, user_id))

        if cursor.rowcount == 0:
            return jsonify({'error': '未找到课表或无权访问'}), 404

        conn.commit()

        return jsonify({
            'message': '课表删除成功'
        }), 200

    except sqlite3.Error as e:
        return jsonify({'error': f'数据库错误: {str(e)}'}), 500
    except Exception as e:
        return jsonify({'error': f'删除课表失败: {str(e)}'}), 500
    finally:
        conn.close()

def get_user_current_timetable(user_id):
    """
    获取用户当前的课表上下文信息
    """
    if not user_id:
        return "用户未登录，没有课表信息"
    
    try:
        conn = sqlite3.connect('timetable.db')
        cursor = conn.cursor()
        
        # 获取用户的最新课表
        cursor.execute('''
            SELECT courses
            FROM timetables
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT 1
        ''', (user_id,))
        
        result = cursor.fetchone()
        conn.close()
        
        if result:
            user_courses = json.loads(result[0])
            if user_courses:
                # 构建课表上下文描述
                timetable_context = f"用户当前课表包含 {len(user_courses)} 门课程：\n"
                for course in user_courses:
                    timetable_context += f"- {course.get('name', '未知课程')} "
                    if 'sessions' in course and course['sessions']:
                        sessions = course['sessions']
                        timetable_context += f"({sessions[0].get('day_str', '未知')} {sessions[0].get('start', '?')}-{sessions[0].get('end', '?')}节, {sessions[0].get('location', '未知地点')})\n"
                    else:
                        timetable_context += "\n"
                return timetable_context
            else:
                return "用户当前课表为空，没有已选课程"
        else:
            return "用户没有保存的课表"
    except Exception as e:
        print(f"获取用户课表时出错: {str(e)}")
        return "无法获取用户课表信息"

def save_ai_message(user_id, session_id, role, content):
    """
    保存AI对话消息到数据库
    """
    try:
        conn = sqlite3.connect('timetable.db')
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO ai_chat_history (user_id, session_id, message_role, message_content)
            VALUES (?, ?, ?, ?)
        ''', (user_id, session_id, role, content))
        
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        print(f"保存AI消息失败: {str(e)}")
        return False

def get_ai_chat_history(user_id, session_id):
    """
    获取指定用户的AI对话历史
    """
    try:
        conn = sqlite3.connect('timetable.db')
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT message_role, message_content, timestamp
            FROM ai_chat_history
            WHERE user_id = ? AND session_id = ?
            ORDER BY timestamp ASC
        ''', (user_id, session_id))
        
        rows = cursor.fetchall()
        conn.close()
        
        messages = []
        for row in rows:
            messages.append({
                'role': row[0],
                'content': row[1],
                'timestamp': row[2]
            })
        
        return messages
    except Exception as e:
        print(f"获取AI对话历史失败: {str(e)}")
        return []

# 新增：课程喜欢功能API
@app.route('/api/favorite-course', methods=['POST'])
def favorite_course():
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    data = request.get_json()
    course_id = data.get('course_id')
    course_name = data.get('course_name')
    course_info = data.get('course_info', '')  # 可选的课程详细信息

    if not course_id or not course_name:
        return jsonify({'error': '缺少课程ID或课程名称'}), 400

    try:
        conn = sqlite3.connect('timetable.db')
        c = conn.cursor()
        
        # 插入或替换喜欢的课程
        c.execute("""
            INSERT OR REPLACE INTO user_favorites (user_id, course_id, course_name, course_info)
            VALUES (?, ?, ?, ?)
        """, (user_id, course_id, course_name, json.dumps(course_info) if course_info else ''))
        
        conn.commit()
        conn.close()
        return jsonify({'message': '课程已添加到喜欢列表'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/unfavorite-course', methods=['DELETE'])
def unfavorite_course():
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    data = request.get_json()
    course_id = data.get('course_id')

    if not course_id:
        return jsonify({'error': '缺少课程ID'}), 400

    try:
        conn = sqlite3.connect('timetable.db')
        c = conn.cursor()
        
        c.execute("""
            DELETE FROM user_favorites
            WHERE user_id = ? AND course_id = ?
        """, (user_id, course_id))
        
        if c.rowcount == 0:
            conn.close()
            return jsonify({'error': '课程未被喜欢或不存在'}), 404
        
        conn.commit()
        conn.close()
        return jsonify({'message': '课程已从喜欢列表中移除'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/user-favorites', methods=['GET'])
def get_user_favorites():
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    try:
        conn = sqlite3.connect('timetable.db')
        c = conn.cursor()
        
        c.execute("""
            SELECT course_id, course_name, course_info, created_at
            FROM user_favorites
            WHERE user_id = ?
            ORDER BY created_at DESC
        """, (user_id,))
        
        rows = c.fetchall()
        conn.close()
        
        favorites = []
        for row in rows:
            favorite = {
                'course_id': row[0],
                'course_name': row[1],
                'created_at': row[3]
            }
            # 尝试解析课程信息
            try:
                if row[2]:
                    favorite['course_info'] = json.loads(row[2])
            except:
                favorite['course_info'] = row[2]
            
            favorites.append(favorite)
        
        return jsonify(favorites), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/check-favorite', methods=['POST'])
def check_favorite():
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    data = request.get_json()
    course_id = data.get('course_id')

    if not course_id:
        return jsonify({'error': '缺少课程ID'}), 400

    try:
        conn = sqlite3.connect('timetable.db')
        c = conn.cursor()
        
        c.execute("""
            SELECT 1
            FROM user_favorites
            WHERE user_id = ? AND course_id = ?
        """, (user_id, course_id))
        
        is_favorite = c.fetchone() is not None
        conn.close()
        
        return jsonify({'is_favorite': is_favorite}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# 新增：AI顾问功能
@app.route('/api/ai-advisor', methods=['POST'])
def ai_advisor():
    data = request.get_json()
    user_message = data.get('message', '')
    user_id = data.get('userId', '')
    courses = data.get('courses', [])
    selected_courses = data.get('selectedCourses', [])
    # 接收前端计算的课表上下文
    timetable_context = data.get('timetableContext', '')
    session_id = data.get('sessionId', 'default_session')  # 添加会话ID

    if not user_message:
        return jsonify({'error': '消息内容不能为空'}), 400

    # 保存用户消息到数据库
    save_ai_message(user_id, session_id, 'user', user_message)

    # 获取用户数据库中的课表信息
    user_timetable_from_db = get_user_current_timetable(user_id)
    
    # 获取历史对话记录
    history_messages = get_ai_chat_history(user_id, session_id)
    
    # 构建系统提示词，结合前端和后端的上下文信息
    system_prompt = f"""
    你是一个专业的选课规划助手，你的任务是帮助学生规划课程选择。
    以下是当前可用的课程列表和学生已选的课程信息，以及他们的课表上下文。
    
    学生的提问: {user_message}
    可选课程数量: {len(courses)}
    已选课程数量: {len(selected_courses)}
    
    前端提供的课表上下文:
    {timetable_context}
    
    后端数据库中的课表信息:
    {user_timetable_from_db}
    
    历史对话记录:
    """
    # 添加历史对话
    for msg in history_messages[-5:]:  # 只取最近5条消息
        role = "学生" if msg['role'] == 'user' else "AI助手"
        system_prompt += f"\n{role}: {msg['content']}"
    
    system_prompt += """
    
    请根据学生的提问和他们的当前课表情况提供专业的选课建议，考虑以下因素：
    1. 时间冲突：检查新建议的课程是否与已选课程时间冲突
    2. 课程负载：考虑学生已选课程的数量，避免过度负担
    3. 课程关联性：推荐与已选课程相关的课程
    4. 课表平衡：考虑一天内课程的分布，避免过于集中或稀疏
    5. 课程密度：分析每日课程数量，提供平衡的建议
    
    如果学生询问具体课程，可以基于已有课程数据提供信息。
    如果学生需要规划建议，可以基于已选课程和可选课程提供建议。
    请用友好、专业的语气回答。
    """
    
    # 准备API请求
    headers = {
        'Content-Type': 'application/json',
        'Authorization': f'Bearer {AI_API_KEY}'
    }
    
    payload = {
        'model': 'deepseek-chat',
        'messages': [
            {'role': 'system', 'content': system_prompt},
            {'role': 'user', 'content': user_message}
        ],
        'temperature': 0.7,
        'max_tokens': 1000
    }
    
    try:
        response = requests.post(AI_API_URL, headers=headers, json=payload)
        response.raise_for_status()
        
        result = response.json()
        ai_reply = result['choices'][0]['message']['content']
        
        # 保存AI回复到数据库
        save_ai_message(user_id, session_id, 'assistant', ai_reply)
        
        return jsonify({
            'reply': ai_reply,
            'status': 'success'
        })
    except requests.exceptions.RequestException as e:
        print(f"AI API request failed: {str(e)}")
        
        # 即使API请求失败，也保存失败信息
        error_msg = '抱歉，AI服务暂时不可用，请稍后再试。'
        save_ai_message(user_id, session_id, 'assistant', error_msg)
        
        return jsonify({
            'reply': error_msg,
            'status': 'error'
        }), 500
    except Exception as e:
        print(f"Error in AI advisor: {str(e)}")
        
        # 即使出现异常，也保存错误信息
        error_msg = '抱歉，处理您的请求时出现了错误。'
        save_ai_message(user_id, session_id, 'assistant', error_msg)
        
        return jsonify({
            'reply': error_msg,
            'status': 'error'
        }), 500

# 新增：获取AI聊天历史记录的API
@app.route('/api/ai-history', methods=['POST'])
def ai_history():
    data = request.get_json()
    user_id = data.get('userId', '')
    session_id = data.get('sessionId', 'default_session')
    
    if not user_id:
        return jsonify({'error': '用户ID不能为空'}), 400
    
    try:
        messages = get_ai_chat_history(user_id, session_id)
        return jsonify({
            'messages': messages,
            'status': 'success'
        })
    except Exception as e:
        print(f"获取AI聊天历史时出错: {str(e)}")
        return jsonify({
            'error': '获取聊天历史失败',
            'status': 'error'
        }), 500

# 新增：更新用户信息的API
@app.route('/api/update_user', methods=['PUT'])
def update_user():
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    if not token:
        return jsonify({'error': 'Unauthorized'}), 401

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_id = payload['user_id']
    except jwt.ExpiredSignatureError:
        return jsonify({'error': 'token已过期'}), 401
    except jwt.InvalidTokenError:
        return jsonify({'error': '无效token'}), 401

    data = request.get_json()
    full_name = data.get('full_name')

    if not full_name:
        return jsonify({'error': '用户名不能为空'}), 400

    try:
        conn = sqlite3.connect('timetable.db')
        c = conn.cursor()
        c.execute("UPDATE users SET full_name = ? WHERE id = ?", (full_name, user_id))
        conn.commit()
        conn.close()
        return jsonify({'message': '用户信息更新成功'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    init_db()  # 初始化数据库
    print("Starting Flask Server on port 5000...")
    app.run(debug=True, port=5000)