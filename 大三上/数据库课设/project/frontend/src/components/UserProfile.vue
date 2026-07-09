<template>
  <div class="profile-container">
    <header class="profile-card">
      <div class="user-main-info">
        <div class="avatar-wrapper">
          <div v-if="!user.avatar_url" class="avatar default-avatar" @click="showEditModal = true">
            {{ user.full_name.charAt(0).toUpperCase() }}
          </div>
          <img v-else :src="user.avatar_url" alt="头像" class="avatar" @click="showEditModal = true"/>
          <div class="avatar-edit-badge">📷</div>
        </div>
        
        <div class="user-details">
          <div v-if="!isEditingName" @click="startEditingName" class="editable-name-group">
            <h1 class="user-name">{{ user.full_name }}</h1>
            <span class="edit-badge">修改名称</span>
          </div>
          <div v-else class="edit-name-container">
            <input 
              v-model="newFullName" 
              type="text" 
              class="name-input"
              @keyup.enter="saveNewName"
              @keyup.esc="cancelEditingName"
              ref="nameInputRef"
            />
            <div class="name-edit-actions">
              <button @click="saveNewName" class="mini-btn save">保存</button>
              <button @click="cancelEditingName" class="mini-btn cancel">取消</button>
            </div>
          </div>
          <p class="user-email">✉️ {{ user.email }}</p>
        </div>
      </div>
      <button @click="logout" class="logout-outline-btn">退出当前账号</button>
    </header>

    <section class="timetables-section">
      <div class="section-header">
        <h2>我的已保存课表</h2>
        <span class="badge">{{ savedTimetables.length }} 份</span>
      </div>

      <div v-if="savedTimetables.length === 0" class="empty-state">
        <div class="empty-icon">📂</div>
        <p>暂无已保存的课表，快去编排一份吧</p>
      </div>

      <div v-else class="timetables-grid">
        <div 
          v-for="timetable in savedTimetables" 
          :key="timetable.id" 
          class="timetable-card"
        >
          <div class="card-content">
            <div class="card-top">
              <div class="timetable-info">
                <h3>{{ timetable.name }}</h3>
                <span class="course-tag">{{ getCourseCount(timetable.courses) }} 门课程</span>
              </div>
              <div class="card-menu">
                <button @click="loadTimetable(timetable)" class="action-btn load" title="加载到主页">
                  <span>应用</span>
                </button>
                <button @click="deleteTimetable(timetable.id)" class="action-btn delete" title="删除">
                  <span>🗑️</span>
                </button>
              </div>
            </div>
            <p class="timetable-remark">{{ timetable.remark || '暂无备注信息...' }}</p>
          </div>
        </div>
      </div>
    </section>
    
    <!-- 喜欢的课程部分 -->
    <section class="liked-courses-section">
      <div class="section-header">
        <h2>我喜欢的课程</h2>
        <span class="badge">{{ likedCourses.length }} 门</span>
      </div>

      <div v-if="likedCourses.length === 0" class="empty-state">
        <div class="empty-icon">❤️</div>
        <p>暂无喜欢的课程，快去课表中添加喜欢的课程吧</p>
      </div>

      <div v-else class="courses-grid">
        <div 
          v-for="course in likedCourses" 
          :key="course.course_id" 
          class="course-card"
        >
          <div class="card-content">
            <div class="card-top">
              <div class="course-info">
                <h3>{{ course.course_name }}</h3>
                <span class="course-id">{{ course.course_id }}</span>
              </div>
              <button @click="removeFromFavorites(course.course_id)" class="action-btn delete" title="取消喜欢">
                <span>❤️</span>
              </button>
            </div>
            <p class="course-remark" v-if="course.course_info && course.course_info.raw_schedule">
              {{ course.course_info.raw_schedule }}
            </p>
            <p class="course-date">喜欢于: {{ formatDate(course.created_at) }}</p>
          </div>
        </div>
      </div>
    </section>
    
    <Transition name="modal-fade">
      <div v-if="showEditModal" class="modal-overlay" @click="closeEditModal">
        <div class="modal-card" @click.stop>
          <div class="modal-header">
            <h3>个人资料设置</h3>
            <button class="close-icon" @click="closeEditModal">✕</button>
          </div>
          <div class="modal-body">
            <div class="avatar-preview-group">
              <div class="preview-item">
                <div v-if="!user.avatar_url" class="avatar default-avatar large">
                  {{ user.full_name.charAt(0).toUpperCase() }}
                </div>
                <img v-else :src="user.avatar_url" alt="当前头像" class="avatar large" />
                <span class="label">当前头像</span>
              </div>
              <div class="preview-divider"></div>
              <div class="preview-item">
                <div class="avatar default-avatar large gray">
                  {{ user.full_name.charAt(0).toUpperCase() }}
                </div>
                <span class="label">默认系统头像</span>
              </div>
            </div>
            
            <div class="form-group">
              <label>修改显示名称</label>
              <input 
                v-model="newFullName" 
                type="text" 
                class="modern-input"
                placeholder="请输入您的姓名"
              />
            </div>

            <div class="modal-footer">
              <button @click="closeEditModal" class="btn-secondary">取消</button>
              <button @click="saveNewName" class="btn-primary">确认保存</button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, nextTick } from 'vue';
import axios from 'axios';

const props = defineProps<{
  user: {
    id: number;
    email: string;
    full_name: string;
    avatar_url?: string;
  };
  currentCourses: any[];
}>();

const emit = defineEmits(['logout', 'load-timetable', 'update-user']);

const savedTimetables = ref<any[]>([]);
const likedCourses = ref<any[]>([]);
const isEditingName = ref(false);
const newFullName = ref(props.user.full_name);
const nameInputRef = ref<HTMLInputElement | null>(null);
const showEditModal = ref(false);

const fetchTimetables = async () => {
  try {
    const token = localStorage.getItem('token');
    if (!token) throw new Error('未找到认证token');
    const response = await axios.get('http://localhost:5000/api/saved_timetables', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    savedTimetables.value = response.data;
  } catch (error: any) {
    console.error('获取课表失败:', error);
  }
};

const fetchLikedCourses = async () => {
  try {
    const token = localStorage.getItem('token');
    if (!token) throw new Error('未找到认证token');
    const response = await axios.get('http://localhost:5000/api/user-favorites', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    likedCourses.value = response.data;
  } catch (error: any) {
    console.error('获取喜欢的课程失败:', error);
    likedCourses.value = [];
  }
};

const removeFromFavorites = async (courseId: string) => {
  if (!confirm('确定要取消喜欢这门课程吗？')) return;
  
  try {
    const token = localStorage.getItem('token');
    const response = await axios.delete(`http://localhost:5000/api/unfavorite-course`, {
      headers: { 'Authorization': `Bearer ${token}` },
      data: { course_id: courseId }
    });
    
    if (response.status === 200) {
      // 从列表中移除课程
      likedCourses.value = likedCourses.value.filter(course => course.course_id !== courseId);
      alert('已从喜欢列表中移除');
    }
  } catch (error: any) {
    alert('取消喜欢失败: ' + (error.response?.data?.error || error.message));
  }
};

const formatDate = (dateString: string) => {
  const date = new Date(dateString);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
};

const loadTimetable = (timetable: any) => {
  try {
    const courses = JSON.parse(timetable.courses);
    emit('load-timetable', courses);
  } catch (e) {
    alert('加载课表失败');
  }
};

const deleteTimetable = async (id: number) => {
  if (!confirm('确定要删除这个课表吗？')) return;
  try {
    const token = localStorage.getItem('token');
    await axios.delete(`http://localhost:5000/api/saved_timetables/${id}`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    await fetchTimetables();
  } catch (error: any) {
    alert('删除失败');
  }
};

const getCourseCount = (coursesJson: string) => {
  try {
    const courses = JSON.parse(coursesJson);
    return Array.isArray(courses) ? courses.length : 0;
  } catch (e) { return 0; }
};

const logout = () => {
  localStorage.removeItem('token');
  localStorage.removeItem('user');
  emit('logout');
};

const startEditingName = () => {
  isEditingName.value = true;
  newFullName.value = props.user.full_name;
  nextTick(() => nameInputRef.value?.focus());
};

const saveNewName = async () => {
  if (!newFullName.value.trim()) return alert('用户名不能为空');
  if (newFullName.value === props.user.full_name) return isEditingName.value = false;
  
  try {
    const token = localStorage.getItem('token');
    const response = await axios.put(
      'http://localhost:5000/api/update_user', 
      { full_name: newFullName.value },
      { headers: { 'Authorization': `Bearer ${token}` }}
    );
    
    if (response.status === 200) {
      const updatedUser = { ...props.user, full_name: newFullName.value };
      localStorage.setItem('user', JSON.stringify(updatedUser));
      emit('update-user', updatedUser);
      isEditingName.value = false;
      showEditModal.value = false;
    }
  } catch (error: any) {
    alert('更新失败');
  }
};

const cancelEditingName = () => {
  isEditingName.value = false;
  newFullName.value = props.user.full_name;
};

const closeEditModal = () => {
  showEditModal.value = false;
  cancelEditingName();
};

onMounted(async () => {
  await fetchTimetables();
  await fetchLikedCourses();
});
</script>

<style scoped>
.profile-container {
  padding: 32px;
  max-width: 1000px;
  margin: 0 auto;
  animation: fadeIn 0.4s ease-out;
}

/* 用户信息卡片优化 */
.profile-card {
  background: white;
  border-radius: 20px;
  padding: 32px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 10px 25px -5px rgba(0,0,0,0.05);
  border: 1px solid #f1f5f9;
  margin-bottom: 40px;
}

.user-main-info {
  display: flex;
  align-items: center;
  gap: 24px;
}

.avatar-wrapper {
  position: relative;
  cursor: pointer;
}

.avatar {
  width: 90px;
  height: 90px;
  border-radius: 24px;
  object-fit: cover;
  transition: all 0.3s;
  box-shadow: 0 4px 12px rgba(99, 102, 241, 0.2);
}

.default-avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #6366f1 0%, #4338ca 100%);
  color: white;
  font-size: 32px;
  font-weight: 700;
}

.avatar-edit-badge {
  position: absolute;
  bottom: -5px;
  right: -5px;
  background: white;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  border: 2px solid #f8fafc;
}

.user-name {
  margin: 0;
  font-size: 28px;
  font-weight: 800;
  color: #1e293b;
}

.editable-name-group {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
  padding: 4px 8px;
  margin-left: -8px;
  border-radius: 8px;
  transition: background 0.2s;
}

.editable-name-group:hover {
  background: #f1f5f9;
}

.edit-badge {
  font-size: 12px;
  background: #e0e7ff;
  color: #4338ca;
  padding: 2px 8px;
  border-radius: 6px;
  opacity: 0;
  transition: opacity 0.2s;
}

.editable-name-group:hover .edit-badge {
  opacity: 1;
}

.user-email {
  margin: 4px 0 0 0;
  color: #64748b;
  font-size: 15px;
}

.logout-outline-btn {
  padding: 10px 20px;
  background: transparent;
  color: #ef4444;
  border: 1.5px solid #fee2e2;
  border-radius: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.logout-outline-btn:hover {
  background: #fef2f2;
  border-color: #ef4444;
}

/* 课表网格优化 */
.section-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 24px;
}

.section-header h2 {
  margin: 0;
  font-size: 20px;
  color: #1e293b;
}

.badge {
  background: #f1f5f9;
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 13px;
  color: #64748b;
  font-weight: 600;
}

.timetables-section {
  margin-bottom: 48px;  /* 添加底部间距 */
}

.timetables-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
}

.courses-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
}

.timetable-card, .course-card {
  background: white;
  border-radius: 16px;
  border: 1px solid #e2e8f0;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  overflow: hidden;
}

.timetable-card:hover, .course-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 20px -8px rgba(0,0,0,0.1);
  border-color: #6366f1;
}

.card-content {
  padding: 20px;
}

.card-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.timetable-info h3, .course-info h3 {
  margin: 0 0 6px 0;
  font-size: 17px;
  color: #1e293b;
}

.course-id {
  font-size: 12px;
  color: #64748b;
  background: #f1f5f9;
  padding: 2px 8px;
  border-radius: 6px;
}

.course-tag {
  font-size: 12px;
  color: #6366f1;
  background: #eef2ff;
  padding: 2px 10px;
  border-radius: 20px;
  font-weight: 600;
}

.card-menu {
  display: flex;
  gap: 8px;
}

.action-btn {
  padding: 6px 12px;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-size: 13px;
  font-weight: 600;
  transition: all 0.2s;
}

.action-btn.load {
  background: #6366f1;
  color: white;
}

.action-btn.delete {
  background: #f8fafc;
  color: #94a3b8;
}

.action-btn.delete:hover {
  background: #fee2e2;
  color: #ef4444;
}

.timetable-remark, .course-remark {
  font-size: 14px;
  color: #64748b;
  margin: 0;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.5;
}

.course-date {
  font-size: 12px;
  color: #94a3b8;
  margin: 8px 0 0 0;
}

/* 弹窗样式优化 */
.modal-overlay {
  background: rgba(15, 23, 42, 0.6);
  backdrop-filter: blur(4px);
}

.modal-card {
  background: white;
  border-radius: 24px;
  width: 440px;
  box-shadow: 0 25px 50px -12px rgba(0,0,0,0.25);
}

.modal-header {
  padding: 24px;
  border-bottom: 1px solid #f1f5f9;
}

.close-icon {
  background: #f1f5f9;
  border: none;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  cursor: pointer;
  color: #64748b;
}

.avatar-preview-group {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 32px;
  padding: 20px 0;
}

.preview-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.preview-item .label {
  font-size: 12px;
  color: #94a3b8;
}

.preview-divider {
  width: 1px;
  height: 40px;
  background: #e2e8f0;
}

.modern-input {
  width: 100%;
  padding: 12px 16px;
  border: 1.5px solid #e2e8f0;
  border-radius: 12px;
  font-size: 15px;
  transition: all 0.2s;
}

.modern-input:focus {
  outline: none;
  border-color: #6366f1;
  box-shadow: 0 0 0 4px rgba(99, 102, 241, 0.1);
}

.modal-footer {
  display: flex;
  gap: 12px;
  margin-top: 32px;
}

.btn-primary {
  flex: 1;
  background: #6366f1;
  color: white;
  border: none;
  padding: 12px;
  border-radius: 12px;
  font-weight: 600;
  cursor: pointer;
}

.btn-secondary {
  flex: 1;
  background: #f1f5f9;
  color: #475569;
  border: none;
  padding: 12px;
  border-radius: 12px;
  font-weight: 600;
  cursor: pointer;
}

.empty-state {
  text-align: center;
  padding: 60px;
  background: #f8fafc;
  border-radius: 20px;
  border: 2px dashed #e2e8f0;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

.modal-fade-enter-active, .modal-fade-leave-active { transition: opacity 0.3s; }
.modal-fade-enter-from, .modal-fade-leave-to { opacity: 0; }
</style>