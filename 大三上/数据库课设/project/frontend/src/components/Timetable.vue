<script setup lang="ts">
import { computed, ref } from 'vue';
import type { Course } from '../types';
import axios from 'axios';

// 1. Props 定义
const props = defineProps<{
  courses: Course[],
  allCourses?: Course[]
}>();

// 2. Emits 定义
const emit = defineEmits<{
  (e: 'remove-course', id: string): void,
  (e: 'addCourse', course: Course): void,
  (e: 'save-timetable'): void
}>();

// 3. 状态管理
const currentWeek = ref(1);
const totalWeeks = 16;
const weeks = Array.from({ length: totalWeeks }, (_, i) => i + 1);
const days = ['一', '二', '三', '四', '五', '六', '日'];
const sections = Array.from({ length: 11 }, (_, i) => i + 1);

const showModal = ref(false);
const selectedDay = ref(0);
const selectedSection = ref(1);
const searchQuery = ref('');

// 新增状态：课程详情modal
const showCourseDetailModal = ref(false);
const selectedCourse = ref<any>(null);
const isCourseFavorite = ref(false);

const availableCourses = computed(() => props.allCourses || props.courses);

// 4. 工具函数
const getCourseColor = (id: string) => {
  let hash = 0;
  for (let i = 0; i < id.length; i++) {
    hash = id.charCodeAt(i) + ((hash << 5) - hash);
  }
  const hue = Math.abs(hash % 360);
  return `hsl(${hue}, 75%, 90%)`;
};

const parseWeeks = (weekStr: string): number[] => {
  const weeks = new Set<number>();
  if (!weekStr) return [];
  const segments = weekStr.trim().split(/\s+/);
  segments.forEach(seg => {
    if (!seg) return;
    let step = 1;
    let remainder = -1;
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

// 5. 计算属性
const scheduleBlocks = computed(() => {
  const blocks: any[] = [];
  props.courses.forEach(course => {
    course.sessions.forEach(session => {
      const courseWeeks = parseWeeks(session.weeks);
      if (!courseWeeks.includes(currentWeek.value)) return;
      blocks.push({
        id: course.id,
        name: course.name,
        teacher: session.teacher,
        location: session.location,
        weeks: session.weeks,
        col: session.day + 2,
        rowStart: session.start + 1,
        rowSpan: session.end - session.start + 1,
        color: getCourseColor(course.id)
      });
    });
  });
  return blocks;
});

const filteredAvailableCourses = computed(() => {
  const query = searchQuery.value.toLowerCase().trim();
  return availableCourses.value.filter(course => {
    const hasSessionInTimeSlot = course.sessions.some(session => {
      const courseWeeks = parseWeeks(session.weeks);
      const isInCurrentWeek = courseWeeks.includes(currentWeek.value);
      const isOnSelectedDay = session.day === selectedDay.value;
      const isInSection = session.start <= selectedSection.value && session.end >= selectedSection.value;
      return isInCurrentWeek && isOnSelectedDay && isInSection;
    });
    const isAlreadySelected = props.courses.some(selectedCourse => selectedCourse.id === course.id);
    
    const matchesSearch = !query || 
      course.name.toLowerCase().includes(query) || 
      course.id.toLowerCase().includes(query) || 
      course.teacher_display.toLowerCase().includes(query);

    return hasSessionInTimeSlot && !isAlreadySelected && matchesSearch;
  });
});

// 6. 交互逻辑
const switchWeek = (week: number) => { currentWeek.value = week; };
const prevWeek = () => { if (currentWeek.value > 1) currentWeek.value--; };
const nextWeek = () => { if (currentWeek.value < totalWeeks) currentWeek.value++; };

const showAvailableCourses = (day: number, section: number) => {
  selectedDay.value = day;
  selectedSection.value = section;
  showModal.value = true;
  searchQuery.value = '';
};

const closeModal = () => { showModal.value = false; };

const addCourseToSelection = (course: Course) => {
  for (const existCourse of props.courses) {
    if (existCourse.name === course.name && existCourse.id.slice(0, -2) === course.id.slice(0, -2)) {
      alert(`您已选择课程《${existCourse.name}》(${existCourse.id})`);
      return;
    }
  }
  emit('addCourse', course);
  closeModal();
};

const showCourseDetail = (block: any) => {
  const course = props.courses.find(c => c.id === block.id);
  if (course) {
    selectedCourse.value = {
      ...course,
      location: block.location,
      weeks: block.weeks
    };
    // 检查是否已收藏
    checkIfFavorite(course.id);
    showCourseDetailModal.value = true;
  }
};

const closeCourseDetailModal = () => {
  showCourseDetailModal.value = false;
  selectedCourse.value = null;
};

const toggleFavorite = async () => {
  if (!selectedCourse.value) return;
  
  try {
    const token = localStorage.getItem('token');
    if (!token) {
      alert('请先登录');
      return;
    }

    if (isCourseFavorite.value) {
      // 取消收藏
      const response = await axios.delete('http://localhost:5000/api/unfavorite-course', {
        headers: { 'Authorization': `Bearer ${token}` },
        data: { course_id: selectedCourse.value.id }
      });
      if (response.status === 200) {
        isCourseFavorite.value = false;
        alert('已从喜欢列表中移除');
      }
    } else {
      // 添加收藏
      const response = await axios.post('http://localhost:5000/api/favorite-course', {
        course_id: selectedCourse.value.id,
        course_name: selectedCourse.value.name,
        course_info: selectedCourse.value
      }, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (response.status === 200) {
        isCourseFavorite.value = true;
        alert('已添加到喜欢列表');
      }
    }
  } catch (error: any) {
    console.error('操作失败:', error);
    alert('操作失败: ' + (error.response?.data?.error || error.message));
  }
};

const checkIfFavorite = async (courseId: string) => {
  try {
    const token = localStorage.getItem('token');
    if (!token) return;
    
    const response = await axios.post('http://localhost:5000/api/check-favorite', {
      course_id: courseId
    }, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    isCourseFavorite.value = response.data.is_favorite;
  } catch (error) {
    console.error('检查收藏状态失败:', error);
    isCourseFavorite.value = false;
  }
};
</script>

<template>
  <div class="timetable-wrapper">
    <div class="timetable-header">
      <div class="header-info">
        <div class="title-row">
          <h2>第 {{ currentWeek }} 周课表</h2>
          <span class="badge">{{ props.courses.length }} 门已选</span>
        </div>
      </div>
      
      <div class="week-controls">
        <div class="nav-group">
          <button @click="prevWeek" class="nav-btn" :disabled="currentWeek <= 1">‹</button>
          <div class="week-pill">
            <span v-for="week in weeks" :key="week" 
                  :class="{ 'week-item': true, 'active': week === currentWeek }"
                  @click="switchWeek(week)">
              {{ week }}
            </span>
          </div>
          <button @click="nextWeek" class="nav-btn" :disabled="currentWeek >= totalWeeks">›</button>
        </div>
        <button @click="$emit('save-timetable')" class="save-btn">保存课表</button>
      </div>
    </div>
    
    <div class="timetable-scroll-area">
      <div class="timetable-grid">
        <div class="grid-header time-col">节次</div>
        <div v-for="day in days" :key="day" class="grid-header">周{{ day }}</div>

        <div v-for="sec in sections" :key="`sec-${sec}`" class="time-index" :style="{ gridRow: sec + 1, gridColumn: 1 }">
          {{ sec }}
        </div>

        <template v-for="(day, dayIndex) in days" :key="`col-${dayIndex}`">
          <div v-for="sec in sections" :key="`cell-${dayIndex}-${sec}`" 
               class="grid-cell-clickable"
               :style="{ gridColumn: dayIndex + 2, gridRow: sec + 1 }"
               @click="showAvailableCourses(dayIndex, sec)">
            <span class="add-icon">+</span>
          </div>
        </template>

        <div v-for="(block, idx) in scheduleBlocks" :key="`${block.id}-${idx}`" 
             class="course-card"
             :style="{
               gridColumn: block.col,
               gridRow: `${block.rowStart} / span ${block.rowSpan}`,
               backgroundColor: block.color
             }"
             @click.stop="showCourseDetail(block)">
          <div class="card-inner">
            <div class="card-title">{{ block.name }}</div>
            <div class="card-loc">📍 {{ block.location }}</div>
            <div class="card-teacher">{{ block.teacher }}</div>
            <button class="card-del" @click.stop="$emit('remove-course', block.id)">✕</button>
          </div>
        </div>
      </div>
    </div>
    
    <Transition name="fade">
      <div v-if="showModal" class="modal-backdrop" @click="closeModal">
        <div class="modal-window" @click.stop>
          <div class="modal-head">
            <div class="modal-title-group">
              <h3>周{{ days[selectedDay] }} 第{{ selectedSection }}节 可选</h3>
              <p class="modal-subtitle">符合当前时间段的课程</p>
            </div>
            <button @click="closeModal" class="close-x">✕</button>
          </div>
          <div class="modal-body">
            <input v-model="searchQuery" placeholder="搜索课程名、教师或 ID..." class="search-bar" />
            <div class="course-list">
              <div v-for="course in filteredAvailableCourses" :key="course.id" class="list-item" @click="addCourseToSelection(course)">
                <div class="item-main">
                  <span class="name">{{ course.name }}</span>
                  <span class="code">{{ course.id }}</span>
                </div>
                <div class="item-sub">{{ course.teacher_display }} | {{ course.raw_schedule }}</div>
              </div>
              <div v-if="filteredAvailableCourses.length === 0" class="empty">
                没有找到相关课程 
              </div>
            </div>
          </div>
        </div>
      </div>
    </Transition>
    
    <!-- 课程详情Modal -->
    <Transition name="fade">
      <div v-if="showCourseDetailModal" class="modal-backdrop" @click="closeCourseDetailModal">
        <div class="modal-window" @click.stop style="width: 500px;">
          <div class="modal-head">
            <div class="modal-title-group">
              <h3>{{ selectedCourse?.name }}</h3>
              <p class="modal-subtitle">{{ selectedCourse?.id }}</p>
            </div>
            <button @click="closeCourseDetailModal" class="close-x">✕</button>
          </div>
          <div class="modal-body">
            <div class="course-detail-info">
              <div class="detail-row">
                <span class="detail-label">教师:</span>
                <span class="detail-value">{{ selectedCourse?.teacher_display }}</span>
              </div>
              <div class="detail-row">
                <span class="detail-label">教室:</span>
                <span class="detail-value">{{ selectedCourse?.location }}</span>
              </div>
              <div class="detail-row">
                <span class="detail-label">时间:</span>
                <span class="detail-value">{{ selectedCourse?.weeks }}</span>
              </div>
              <div class="detail-row" v-if="selectedCourse?.raw_schedule">
                <span class="detail-label">排课信息:</span>
                <span class="detail-value">{{ selectedCourse?.raw_schedule }}</span>
              </div>
            </div>
            <div class="modal-footer" style="margin-top: 20px;">
              <button @click="toggleFavorite" class="favorite-btn" :class="{ 'favorited': isCourseFavorite }">
                {{ isCourseFavorite ? '❤️ 已喜欢' : '🤍 喜欢' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
/* 保持原有风格不变 */
.timetable-wrapper {
  background: #f8fafc;
  padding: 24px;
  border-radius: 16px;
  height: 100%; /* 这里建议父级有固定高度或 100vh */
  display: flex;
  flex-direction: column;
  font-family: 'Inter', -apple-system, sans-serif;
  box-sizing: border-box;
}

/* 关键改动 2：滚动容器样式 */
.timetable-scroll-area {
  flex: 1;
  overflow-y: auto;
  border-radius: 16px;
}

.timetable-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  margin-bottom: 24px;
}
.title-row { display: flex; align-items: center; gap: 12px; }
.header-info h2 { margin: 0; color: #1e293b; font-size: 1.6rem; font-weight: 800; }
.badge { font-size: 0.75rem; color: #2563eb; background: #dbeafe; padding: 4px 10px; border-radius: 20px; font-weight: 600; }

.week-controls { display: flex; align-items: center; gap: 16px; }
.nav-group { display: flex; align-items: center; gap: 8px; }
.nav-btn { 
  border: 1px solid #e2e8f0; background: #fff; width: 36px; height: 36px; 
  border-radius: 10px; cursor: pointer; transition: all 0.2s; font-size: 1.2rem;
}
.nav-btn:hover:not(:disabled) { background: #f1f5f9; border-color: #cbd5e1; }
.nav-btn:disabled { opacity: 0.5; cursor: not-allowed; }

.save-btn { 
  background: #2563eb; color: white; border: none; padding: 0 24px; height: 38px;
  border-radius: 10px; font-weight: 600; cursor: pointer; white-space: nowrap;
  transition: all 0.2s; box-shadow: 0 4px 6px -1px rgba(37, 99, 235, 0.2);
}
.save-btn:hover { background: #1d4ed8; transform: translateY(-1px); box-shadow: 0 6px 12px -2px rgba(37, 99, 235, 0.3); }

.week-pill { 
  background: #fff; padding: 4px; border-radius: 12px; border: 1px solid #e2e8f0; 
  display: flex; gap: 2px; max-width: 420px; flex-wrap: wrap; 
}
.week-item { 
  width: 30px; height: 30px; display: flex; align-items: center; justify-content: center; 
  font-size: 0.85rem; cursor: pointer; border-radius: 8px; color: #64748b; transition: 0.2s;
}
.week-item:hover { background: #f1f5f9; color: #1e293b; }
.week-item.active { background: #2563eb; color: white; font-weight: 700; }

/* 关键改动 3：网格行列定义 */
.timetable-grid {
  display: grid;
  grid-template-columns: 60px repeat(7, 1fr);
  /* 显式定义 11 节课高度，防止压缩 */
  grid-template-rows: 45px repeat(11, 75px);
  gap: 1px;
  background: #e2e8f0;
  border: 1px solid #e2e8f0;
  border-radius: 16px;
  overflow: hidden;
  position: relative;
}

/* 剩下的样式完全保留 */
.grid-header, .time-index { background: #f8fafc; display: flex; align-items: center; justify-content: center; font-weight: 700; color: #64748b; font-size: 0.85rem; }
.time-col { background: #f1f5f9; }

.grid-cell-clickable {
  background: #fff; cursor: pointer; transition: all 0.2s; z-index: 1;
  display: flex; align-items: center; justify-content: center;
}
.grid-cell-clickable .add-icon { color: #e2e8f0; font-size: 1.5rem; opacity: 0; transition: 0.2s; }
.grid-cell-clickable:hover { background: #f0f7ff; }
.grid-cell-clickable:hover .add-icon { opacity: 1; color: #bfdbfe; }

.course-card {
  margin: 3px; padding: 10px; border-radius: 10px; z-index: 2; cursor: pointer; 
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  border-left: 4px solid rgba(0,0,0,0.1);
  position: relative; overflow: hidden;
}
.course-card:hover { transform: scale(1.02); box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1); z-index: 10; }
.card-title { font-weight: 800; font-size: 0.9rem; color: #1e293b; margin-bottom: 6px; line-height: 1.3; }
.card-loc, .card-teacher { font-size: 0.75rem; color: #475569; margin-top: 2px; }

.card-del {
  position: absolute; top: 6px; right: 6px; width: 22px; height: 22px; 
  background: rgba(255,255,255,0.6); border: none; border-radius: 6px; 
  cursor: pointer; display: none; align-items: center; justify-content: center; font-size: 12px; color: #ef4444;
}
.course-card:hover .card-del { display: flex; }
.card-del:hover { background: #fee2e2; color: #ef4444; }

.modal-backdrop {
  position: fixed; inset: 0; background: rgba(15, 23, 42, 0.5); 
  backdrop-filter: blur(8px); display: flex; align-items: center; justify-content: center; z-index: 1000;
}
.modal-window { 
  background: #fff; border-radius: 20px; width: 520px; max-height: 85vh; 
  display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.25); 
}
.modal-head { 
  padding: 20px 24px; border-bottom: 1px solid #f1f5f9; display: flex; 
  justify-content: space-between; align-items: flex-start; 
}
.modal-title-group h3 { margin: 0; font-size: 1.2rem; color: #1e293b; }
.modal-subtitle { margin: 4px 0 0 0; font-size: 0.85rem; color: #94a3b8; }

.close-x {
  background: #f1f5f9; border: none; width: 32px; height: 32px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center; cursor: pointer;
  color: #64748b; transition: all 0.2s;
}
.close-x:hover { background: #fee2e2; color: #ef4444; transform: rotate(90deg); }

.modal-body { padding: 24px; overflow-y: auto; }
.search-bar { 
  width: 100%; box-sizing: border-box; padding: 12px 16px; border-radius: 12px; 
  border: 1px solid #e2e8f0; background: #f8fafc; margin-bottom: 20px;
  font-size: 1rem; outline: none; transition: all 0.2s;
}
.search-bar:focus { border-color: #2563eb; background: #fff; box-shadow: 0 0 0 4px rgba(37, 99, 235, 0.1); }

.course-list { display: flex; flex-direction: column; gap: 10px; }
.list-item { 
  padding: 16px; background: #f8fafc; border: 1px solid #f1f5f9; 
  border-radius: 12px; cursor: pointer; transition: all 0.2s; 
}
.list-item:hover { background: #eff6ff; border-color: #bfdbfe; transform: translateX(4px); }
.item-main { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; }
.item-main .name { font-weight: 700; color: #1e293b; }
.item-main .code { font-size: 0.75rem; color: #94a3b8; background: #fff; padding: 2px 6px; border-radius: 4px; border: 1px solid #e2e8f0; }
.item-sub { font-size: 0.85rem; color: #64748b; }

.empty { text-align: center; color: #94a3b8; padding: 40px 0; font-size: 0.9rem; }

.fade-enter-active, .fade-leave-active { transition: opacity 0.3s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }

/* 课程详情Modal样式 */
.course-detail-info { margin-bottom: 20px; }
.detail-row { display: flex; margin-bottom: 12px; }
.detail-label { font-weight: 600; color: #334155; width: 80px; flex-shrink: 0; }
.detail-value { color: #64748b; flex: 1; }

.favorite-btn {
  padding: 12px 20px;
  border-radius: 12px;
  border: none;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 8px;
  justify-content: center;
}

.favorite-btn:not(.favorited) {
  background: #f1f5f9;
  color: #64748b;
}

.favorite-btn.favorited {
  background: #fee2e2;
  color: #ef4444;
}

.favorite-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}

.modal-footer { display: flex; justify-content: flex-end; }
</style>