<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import axios from 'axios';
import CourseList from './components/CourseList.vue';
import Timetable from './components/Timetable.vue';
import Login from './components/Login.vue';
import UserProfile from './components/UserProfile.vue';
import CourseSquare from './components/CourseSquare.vue'; // 新增课程广场组件
import AIAdvisor from './components/AIAdvisor.vue'; // 新增AI顾问组件
import type { Course } from './types';

// --- 状态定义 ---
const allCourses = ref<Course[]>([]);
const selectedCourses = ref<Course[]>([]);
const isSidebarCollapsed = ref(false);
const currentUser = ref<any>(null);
const isLoggedIn = ref(false);
const activeTab = ref('timetable');
const showSaveModal = ref(false);
const saveTimetableName = ref('');
const saveTimetableRemark = ref('');
const savedTimetables = ref<any[]>([]);

const aiQuery = ref('');
const isAiLoading = ref(false);
const aiResultIds = ref<string[] | null>(null);

// --- 核心逻辑 ---
onMounted(async () => {
  const savedUser = localStorage.getItem('user');
  const token = localStorage.getItem('token');
  if (savedUser && token) {
    try {
      currentUser.value = JSON.parse(savedUser);
      isLoggedIn.value = true;
    } catch (error) {
      localStorage.removeItem('user');
      localStorage.removeItem('token');
    }
  }
  if (isLoggedIn.value) { await loadCourses(); }
});

const loadCourses = async () => {
  try {
    const res = await axios.get('http://localhost:5000/api/courses');
    allCourses.value = res.data;
    await loadSavedTimetables();
  } catch (error) {
    console.error("Failed to load courses:", error);
    alert("无法连接到后端，请确保 Flask 服务已启动 (port 5000)");
  }
};

const loadSavedTimetables = async () => {
  try {
    const response = await axios.get('http://localhost:5000/api/saved_timetables', {
      headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}` }
    });
    savedTimetables.value = response.data;
  } catch (error) { console.error('加载已保存的课表失败:', error); }
};

const handleLogin = (user: any) => {
  currentUser.value = user;
  isLoggedIn.value = true;
  loadCourses();
};

const handleLogout = () => {
  currentUser.value = null;
  isLoggedIn.value = false;
  localStorage.removeItem('user');
  localStorage.removeItem('token');
  activeTab.value = 'timetable';
};

const updateCurrentUser = (updatedUser: any) => {
  currentUser.value = updatedUser;
  localStorage.setItem('user', JSON.stringify(updatedUser));
};

const displayCourses = computed(() => {
  if (aiResultIds.value === null) return allCourses.value;
  return allCourses.value.filter(c => aiResultIds.value?.includes(c.id));
});

const handleAiSearch = async () => {
  if (!aiQuery.value.trim()) return;
  isAiLoading.value = true;
  aiResultIds.value = null;
  try {
    const res = await axios.post('http://localhost:5000/api/ai-search', { query: aiQuery.value });
    const recommendedCourses = res.data;
    aiResultIds.value = recommendedCourses.map((c: any) => c.id);
  } catch (error) {
    alert("AI 推荐失败，请检查后端服务连接");
  } finally {
    isAiLoading.value = false;
  }
};

const clearSearch = () => { aiQuery.value = ''; aiResultIds.value = null; };

const parseWeeks = (weekStr: string): number[] => {
  const weeks = new Set<number>();
  if (!weekStr) return [];
  const segments = weekStr.trim().split(/\s+/);
  segments.forEach(seg => {
    if (!seg) return;
    let step = 1; let remainder = -1;
    if (seg.includes('单')) { step = 2; remainder = 1; seg = seg.replace('单', ''); } 
    else if (seg.includes('双')) { step = 2; remainder = 0; seg = seg.replace('双', ''); }
    if (seg.includes('-')) {
      const parts = seg.split('-');
      const start = parseInt(parts[0], 10);
      const end = parseInt(parts[1], 10);
      if (!isNaN(start) && !isNaN(end)) {
        for (let i = start; i <= end; i++) {
          if (remainder !== -1 && i % 2 !== remainder) continue;
          weeks.add(i);
        }
      }
    } else {
      const val = parseInt(seg, 10);
      if (!isNaN(val)) weeks.add(val);
    }
  });
  return Array.from(weeks).sort((a, b) => a - b);
};

const checkConflict = (newCourse: Course, existingCourses: Course[]): string | null => {
  for (const existCourse of existingCourses) {
    for (const existSession of existCourse.sessions) {
      for (const newSession of newCourse.sessions) {
        if (newSession.day === existSession.day && newSession.start <= existSession.end && newSession.end >= existSession.start &&
          parseWeeks(newSession.weeks).some(week => parseWeeks(existSession.weeks).includes(week))) {
          return `${existCourse.name} (${existSession.location})`;
        }
      }
    }
  }
  return null;
};

const addCourse = (course: Course) => {
  if (!isLoggedIn.value) { alert('请先登录'); return; }
  if (selectedCourses.value.some(c => c.id === course.id)) { alert('该课程已在选课列表中'); return; }
  const conflict = checkConflict(course, selectedCourses.value);
  if (conflict) { alert(`与课程 ${conflict} 存在时间冲突`); return; }
  selectedCourses.value.push(course);
};

const removeCourse = (courseId: string) => {
  selectedCourses.value = selectedCourses.value.filter(c => c.id !== courseId);
};

const loadTimetable = (courses: Course[]) => {
  selectedCourses.value = [...courses];
  activeTab.value = 'timetable';
};

const saveCurrentTimetable = async () => {
  if (!saveTimetableName.value.trim()) { alert('请输入课表名称'); return; }
  if (selectedCourses.value.length === 0) { alert('当前没有选择任何课程'); return; }
  try {
    const response = await axios.post('http://localhost:5000/api/save_timetable', {
      name: saveTimetableName.value, remark: saveTimetableRemark.value, courses: selectedCourses.value
    }, {
      headers: { 'Authorization': `Bearer ${localStorage.getItem('token')}`, 'Content-Type': 'application/json' }
    });
    if (response.status === 200) {
      alert('课表保存成功');
      showSaveModal.value = false;
      saveTimetableName.value = ''; saveTimetableRemark.value = '';
    }
  } catch (error) { alert('保存失败，请重试'); }
};

const closeSaveModal = () => { showSaveModal.value = false; saveTimetableName.value = ''; saveTimetableRemark.value = ''; };
</script>

<template>
  <div v-if="!isLoggedIn" class="login-wrapper">
    <Login @login="handleLogin" />
  </div>
  
  <div v-else class="app-container">
    <nav class="top-nav">
      <div class="nav-content">
        <div class="brand">
          <div class="brand-logo">🗓️</div>
          <h1>课程智能管理系统</h1>
        </div>
        <div class="user-info">
          <div class="user-badge" @click="activeTab = 'profile'">
            <div class="user-avatar">{{ currentUser.full_name.charAt(0) }}</div>
            <span class="user-name">{{ currentUser.full_name }}</span>
          </div>
          <div class="nav-divider"></div>
          <button @click="handleLogout" class="logout-btn">
            退出登录
          </button>
        </div>
      </div>
    </nav>

    <div class="main-layout">
      <aside :class="['sidebar', { collapsed: isSidebarCollapsed }]">
        <div class="sidebar-header">
          <h2 v-show="!isSidebarCollapsed">课程探索</h2>
          <button class="toggle-btn" @click="isSidebarCollapsed = !isSidebarCollapsed">
            {{ isSidebarCollapsed ? '→' : '←' }}
          </button>
        </div>
        
        <div class="sidebar-content" v-show="!isSidebarCollapsed">
          <div class="ai-search-card">
            <div class="card-header">✨ AI 智能搜索</div>
            <div class="search-box">
              <input v-model="aiQuery" placeholder="我想学机器学习..." @keyup.enter="handleAiSearch" :disabled="isAiLoading" />
              <button @click="handleAiSearch" :disabled="isAiLoading" class="ai-btn">
                <span v-if="!isAiLoading">搜索</span>
                <div v-else class="loader"></div>
              </button>
            </div>
            <button @click="clearSearch" v-if="aiResultIds !== null" class="clear-btn">
              ↺ 重置搜索结果
            </button>
          </div>
          
          <div class="course-list-wrapper">
            <CourseList :courses="displayCourses" :selected-courses="selectedCourses" @add-course="addCourse" />
          </div>
        </div>
      </aside>

      <main class="main-content">
        <div class="content-container">
          <div class="tab-nav">
            <button :class="['tab-btn', { active: activeTab === 'timetable' }]" @click="activeTab = 'timetable'">我的课表</button>
            <button :class="['tab-btn', { active: activeTab === 'square' }]" @click="activeTab = 'square'">课程广场</button>
            <button :class="['tab-btn', { active: activeTab === 'advisor' }]" @click="activeTab = 'advisor'">选课规划能手</button>
            <button :class="['tab-btn', { active: activeTab === 'profile' }]" @click="activeTab = 'profile'">个人档案</button>
          </div>

          <div class="tab-view">
            <Transition name="fade" mode="out-in">
              <div v-if="activeTab === 'timetable'" class="tab-panel">
                <Timetable :courses="selectedCourses" :all-courses="allCourses" @remove-course="removeCourse" @add-course="addCourse" @save-timetable="showSaveModal = true" />
              </div>
              <div v-else-if="activeTab === 'square'" class="tab-panel">
                <CourseSquare :all-courses="allCourses" @select-course="addCourse" />
              </div>
              <div v-else-if="activeTab === 'advisor'" class="tab-panel">
                <AIAdvisor 
                  :courses="allCourses" 
                  :selected-courses="selectedCourses" 
                  :user-id="currentUser.id" 
                />
              </div>
              <div v-else-if="activeTab === 'profile'" class="tab-panel">
                <UserProfile :user="currentUser" :current-courses="selectedCourses" @logout="handleLogout" @load-timetable="loadTimetable" @update-user="updateCurrentUser" />
              </div>
            </Transition>
          </div>
        </div>
      </main>
    </div>

    <Transition name="modal">
      <div v-if="showSaveModal" class="modal-overlay" @click="closeSaveModal">
        <div class="modal-content" @click.stop>
          <div class="modal-header">
            <h3>保存当前课表</h3>
            <button class="close-btn" @click="closeSaveModal" title="关闭">✕</button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>课表名称 <span class="required">*</span></label>
              <input v-model="saveTimetableName" type="text" placeholder="例如：2024秋季首选" class="form-input" />
            </div>
            <div class="form-group">
              <label>备注</label>
              <textarea v-model="saveTimetableRemark" placeholder="添加备注信息..." class="form-textarea"></textarea>
            </div>
            <div class="form-actions">
              <button @click="closeSaveModal" class="cancel-btn">取消</button>
              <button @click="saveCurrentTimetable" class="save-confirm-btn">确认保存</button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style>
:root {
  --primary: #6366f1;
  --primary-hover: #4f46e5;
  --bg-main: #f8fafc;
  --bg-card: #ffffff;
  --text-main: #1e293b;
  --text-sub: #64748b;
  --shadow-sm: 0 1px 3px rgba(0,0,0,0.12);
  --shadow-md: 0 4px 6px -1px rgba(0,0,0,0.1);
  --radius: 12px;
}

body {
  margin: 0;
  font-family: 'Inter', -apple-system, sans-serif;
  background-color: var(--bg-main);
  color: var(--text-main);
}

.app-container {
  height: 100vh;
  display: flex;
  flex-direction: column;
}

/* 顶部导航美化 */
.top-nav {
  background: rgba(255, 255, 255, 0.85);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid #e2e8f0;
  height: 64px;
  z-index: 100;
}

.nav-content {
  max-width: 1440px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
  height: 100%;
  padding: 0 24px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 12px;
}

.brand-logo { font-size: 24px; }
.brand h1 { font-size: 18px; font-weight: 700; margin: 0; color: var(--primary); }

.user-info {
  display: flex;
  align-items: center;
  gap: 12px;
  background: #ffffff;
  padding: 4px 4px 4px 12px;
  border-radius: 30px;
  border: 1px solid #e2e8f0;
  box-shadow: var(--shadow-sm);
}

.user-badge {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  transition: opacity 0.2s;
}

.user-badge:hover { opacity: 0.8; }
.user-name { font-size: 14px; font-weight: 500; color: var(--text-main); }

.user-avatar {
  width: 28px; height: 28px; border-radius: 50%;
  background: var(--primary); color: white;
  display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold;
}

.nav-divider { width: 1px; height: 16px; background: #e2e8f0; }

.logout-btn {
  background: #fff1f2; color: #e11d48; border: none;
  padding: 6px 16px; border-radius: 20px; cursor: pointer; 
  font-size: 13px; font-weight: 600; transition: all 0.2s;
}
.logout-btn:hover { background: #ffe4e6; transform: translateY(-1px); }

/* 布局控制 */
.main-layout { display: flex; flex: 1; overflow: hidden; padding: 16px; gap: 16px; }

.sidebar {
  width: 360px; background: var(--bg-card); border-radius: var(--radius);
  box-shadow: var(--shadow-md); display: flex; flex-direction: column;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); overflow: hidden;
}

.sidebar.collapsed { width: 60px; }
.sidebar-header { padding: 16px; display: flex; justify-content: space-between; align-items: center; }
.toggle-btn { background: #f1f5f9; border: none; width: 32px; height: 32px; border-radius: 8px; cursor: pointer; }

.sidebar-content { flex: 1; overflow-y: auto; padding: 0 16px 16px; }

.ai-search-card {
  background: linear-gradient(135deg, #f5f3ff 0%, #ede9fe 100%);
  padding: 16px; border-radius: 12px; margin-bottom: 16px;
  border: 1px solid #ddd6fe;
}

.card-header { font-weight: 700; color: #5b21b6; font-size: 14px; margin-bottom: 8px; }

.search-box { display: flex; gap: 8px; margin-bottom: 10px; }
.search-box input { flex: 1; padding: 10px; border: 1px solid #ddd6fe; border-radius: 8px; font-size: 13px; }
.search-box input:focus { outline: none; border-color: var(--primary); box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.1); }

.ai-btn { background: var(--primary); color: white; border: none; padding: 0 16px; border-radius: 8px; cursor: pointer; font-weight: 600; }
.ai-btn:hover { background: var(--primary-hover); }

.clear-btn {
  width: 100%; padding: 8px; background: rgba(255, 255, 255, 0.6);
  border: 1px dashed #c4b5fd; color: #6d28d9; border-radius: 8px;
  cursor: pointer; font-size: 12px; font-weight: 500; transition: all 0.2s;
}
.clear-btn:hover { background: #ffffff; border-style: solid; color: var(--primary); }

/* 内容区美化 */
.main-content { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.content-container {
  background: var(--bg-card); border-radius: var(--radius); box-shadow: var(--shadow-md);
  height: 100%; display: flex; flex-direction: column; overflow: hidden;
}

.tab-nav { display: flex; padding: 8px; background: #f1f5f9; border-radius: var(--radius) var(--radius) 0 0; }
.tab-btn {
  flex: 1; padding: 10px; border: none; background: transparent; cursor: pointer;
  border-radius: 8px; font-weight: 600; color: var(--text-sub); transition: all 0.3s;
}
.tab-btn.active { background: white; color: var(--primary); box-shadow: var(--shadow-sm); }

.tab-view { flex: 1; overflow: hidden; }
.tab-panel { height: 100%; overflow-y: auto; padding: 20px; }

/* 过渡动画 */
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }

.modal-enter-active, .modal-leave-active { transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); }
.modal-enter-from, .modal-leave-to { opacity: 0; transform: scale(0.9) translateY(-20px); }

/* --- 模态框样式修复与美化 --- */
.modal-overlay {
  position: fixed; inset: 0; background: rgba(15, 23, 42, 0.5);
  backdrop-filter: blur(4px); display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.modal-content {
  background: white; border-radius: 16px; width: 480px; max-width: 90vw;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25); overflow: hidden;
}
.modal-header { 
  padding: 16px 24px; border-bottom: 1px solid #f1f5f9; 
  display: flex; justify-content: space-between; align-items: center;
}
.modal-header h3 { margin: 0; font-size: 18px; color: var(--text-main); }

.close-btn {
  background: #f1f5f9; border: none; width: 32px; height: 32px; border-radius: 50%;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  color: var(--text-sub); transition: all 0.2s; font-size: 14px;
}
.close-btn:hover { background: #fee2e2; color: #ef4444; }

.modal-body { padding: 24px; }

.form-group { margin-bottom: 20px; }
.form-group label { 
  display: block; margin-bottom: 8px; font-weight: 600; font-size: 14px; color: var(--text-main);
}
.required { color: #ef4444; margin-left: 4px; }

.form-input, .form-textarea {
  width: 100%; box-sizing: border-box; /* 核心修复：防止 padding 导致溢出 */
  padding: 12px; border: 1px solid #e2e8f0; border-radius: 8px; 
  font-family: inherit; font-size: 14px; transition: all 0.2s;
}
.form-input:focus, .form-textarea:focus {
  outline: none; border-color: var(--primary); box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.1);
}
.form-textarea { resize: vertical; min-height: 100px; }

.form-actions { display: flex; gap: 12px; justify-content: flex-end; margin-top: 24px; }
.save-confirm-btn { 
  background: var(--primary); color: white; border: none; 
  padding: 10px 24px; border-radius: 8px; cursor: pointer; font-weight: 600;
  transition: background 0.2s;
}
.save-confirm-btn:hover { background: var(--primary-hover); }

.cancel-btn { 
  background: #f1f5f9; color: var(--text-sub); border: none; 
  padding: 10px 20px; border-radius: 8px; cursor: pointer; font-weight: 500;
}
.cancel-btn:hover { background: #e2e8f0; color: var(--text-main); }

/* AI Loader */
.loader { width: 16px; height: 16px; border: 2px solid #fff; border-bottom-color: transparent; border-radius: 50%; animation: rotation 1s linear infinite; }
@keyframes rotation { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>