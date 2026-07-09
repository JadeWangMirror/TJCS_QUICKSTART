<template>
  <div class="course-square-container">
    <div class="header">
      <h2>课程广场</h2>
      <p>为您推荐以下热门课程</p>
    </div>
    
    <div class="recommended-courses">
      <div 
        v-for="(course, index) in recommendedCourses" 
        :key="course.id"
        class="course-card"
        :style="{ backgroundColor: getCourseColor(course.id) }"
      >
        <div class="course-content">
          <h3 class="course-name">{{ course.name }}</h3>
          <div class="course-details">
            <p class="course-teacher">教师: {{ course.teacher_display }}</p>
            <p class="course-schedule">时间: {{ course.raw_schedule }}</p>
          </div>
          
          <div class="course-actions">
            <button class="select-btn" @click="selectCourse(course)">选择</button>
            <button class="replace-btn" @click="replaceCourse(index)">换一换</button>
          </div>
        </div>
      </div>
      
      <div 
        v-for="n in remainingSlots" 
        :key="`empty-${n}`"
        class="empty-slot"
      >
        <div class="placeholder">
          <p>暂无推荐</p>
          <p>等待推荐</p>
        </div>
      </div>
    </div>
    
    <div class="refresh-section">
      <button class="refresh-btn" @click="refreshAllCourses">刷新全部推荐</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import type { Course } from '../types';

const props = defineProps<{
  allCourses: Course[]
}>();

const emit = defineEmits<{
  (e: 'select-course', course: Course): void
}>();

// 用于存储当前推荐的课程
const recommendedCourses = ref<Course[]>([]);

// 计算剩余插槽数量（总共需要5门课程）
const remainingSlots = computed(() => {
  const needed = 5 - recommendedCourses.value.length;
  return needed > 0 ? needed : 0;
});

// 生成课程颜色
const getCourseColor = (id: string) => {
  let hash = 0;
  for (let i = 0; i < id.length; i++) {
    hash = id.charCodeAt(i) + ((hash << 5) - hash);
  }
  const hue = Math.abs(hash % 360);
  return `hsl(${hue}, 70%, 95%)`;
};

// 随机获取课程
const getRandomCourses = (count: number): Course[] => {
  if (props.allCourses.length === 0) return [];
  
  // 创建一个副本，避免修改原始数据
  const shuffled = [...props.allCourses].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
};

// 初始化推荐课程
const initializeRecommended = () => {
  recommendedCourses.value = getRandomCourses(5);
};

// 更换指定位置的课程
const replaceCourse = (index: number) => {
  if (props.allCourses.length === 0) return;
  
  // 获取当前推荐的课程ID，避免重复
  const currentIds = new Set(recommendedCourses.value.map(c => c.id));
  
  // 找到一个不在当前推荐中的课程
  const availableCourses = props.allCourses.filter(c => !currentIds.has(c.id));
  
  if (availableCourses.length > 0) {
    // 随机选择一个新课程替换
    const randomIndex = Math.floor(Math.random() * availableCourses.length);
    const newCourse = availableCourses[randomIndex];
    
    // 替换指定位置的课程
    recommendedCourses.value[index] = newCourse;
  } else {
    // 如果没有不重复的课程，则从全部课程中随机选一个
    const randomIndex = Math.floor(Math.random() * props.allCourses.length);
    recommendedCourses.value[index] = props.allCourses[randomIndex];
  }
};

// 选择课程
const selectCourse = (course: Course) => {
  emit('select-course', course);
};

// 刷新全部推荐
const refreshAllCourses = () => {
  initializeRecommended();
};

// 组件挂载时初始化推荐课程
onMounted(() => {
  initializeRecommended();
});
</script>

<style scoped>
.course-square-container {
  padding: 24px;
  background: #f8fafc;
  border-radius: 16px;
  font-family: 'Inter', -apple-system, sans-serif;
  max-width: 1200px;
  margin: 0 auto;
}

.header {
  text-align: center;
  margin-bottom: 30px;
}

.header h2 {
  color: #1e293b;
  font-size: 1.8rem;
  margin: 0 0 8px 0;
  font-weight: 700;
}

.header p {
  color: #64748b;
  font-size: 1rem;
  margin: 0;
}

.recommended-courses {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}

.course-card {
  border-radius: 16px;
  padding: 20px;
  color: #1e293b;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
  transition: all 0.3s ease;
  display: flex;
  flex-direction: column;
  height: 220px;
}

.course-card:hover {
  transform: translateY(-5px);
  box-shadow: 0 10px 15px rgba(0, 0, 0, 0.1);
}

.course-content {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.course-name {
  font-size: 1.2rem;
  font-weight: 700;
  margin: 0 0 10px 0;
  color: #1e293b;
  flex-grow: 1;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.course-details {
  flex-grow: 1;
  min-height: 0;
  overflow-y: auto;
  margin-bottom: 10px;
  max-height: 70px;
}

.course-teacher,
.course-schedule {
  font-size: 0.9rem;
  color: #334155;
  margin: 5px 0;
  word-break: break-word;
  overflow-wrap: break-word;
}

.course-actions {
  display: flex;
  gap: 10px;
  margin-top: auto;
}

.select-btn,
.replace-btn {
  flex: 1;
  padding: 8px 12px;
  border-radius: 8px;
  border: none;
  cursor: pointer;
  font-weight: 600;
  transition: all 0.2s;
  font-size: 0.9rem;
}

.select-btn {
  background-color: #2563eb;
  color: white;
}

.select-btn:hover {
  background-color: #1d4ed8;
}

.replace-btn {
  background-color: #e2e8f0;
  color: #334155;
}

.replace-btn:hover {
  background-color: #cbd5e1;
}

.empty-slot {
  border: 2px dashed #cbd5e1;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: #f8fafc;
}

.placeholder {
  text-align: center;
  color: #94a3b8;
  font-size: 0.9rem;
}

.refresh-section {
  text-align: center;
}

.refresh-btn {
  background-color: #1e293b;
  color: white;
  border: none;
  padding: 12px 30px;
  border-radius: 10px;
  cursor: pointer;
  font-weight: 600;
  font-size: 1rem;
  transition: all 0.2s;
  box-shadow: 0 4px 6px rgba(30, 41, 59, 0.2);
}

.refresh-btn:hover {
  background-color: #0f172a;
  transform: translateY(-2px);
  box-shadow: 0 6px 12px rgba(30, 41, 59, 0.3);
}
</style>