<script setup lang="ts">
import { ref, computed } from 'vue';
import type { Course } from '../types';

const props = defineProps<{
  courses: Course[],
  selectedCourses: Course[]
}>();

const emit = defineEmits<{
  (e: 'add-course', course: Course): void
}>();

const searchQuery = ref('');

const filteredCourses = computed(() => {
  const query = searchQuery.value.toLowerCase().trim();
  if (!query) return props.courses.slice(0, 50); // 默认只显示前50条避免卡顿

  return props.courses.filter(c => 
    c.name.toLowerCase().includes(query) || 
    c.id.toLowerCase().includes(query) ||
    c.teacher_display.toLowerCase().includes(query)
  ).slice(0, 50);
});

// 添加课程名相同但课号不同的检查函数
const checkSameNameDifferentId = (newCourse: Course, selectedCourses: Course[]): boolean => {
  for (const existCourse of selectedCourses) {
    // 检查课程名是否相同
    if (existCourse.name === newCourse.name) {
      // 检查课号是否只有最后两位不同
      if (existCourse.id.slice(0, -2) === newCourse.id.slice(0, -2)) {
        alert(`您已选择课程《${existCourse.name}》，课号为${existCourse.id}。\n\n不能同时选择课号相似的课程《${newCourse.name}》(${newCourse.id})，请先删除已选课程再添加新课程。`);
        return true;
      }
    }
  }
  return false;
};

// 添加课程到已选列表
const addCourse = (course: Course) => {
  // 检查课程名相同但课号不同的情况
  if (checkSameNameDifferentId(course, props.selectedCourses)) {
    return;
  }
  
  emit('add-course', course);
};
</script>

<template>
  <div class="course-list-container">
    <div class="search-bar">
      <input 
        v-model="searchQuery" 
        placeholder="搜索课名、课号或老师..." 
        type="text"
      />
    </div>
    <div class="list-content">
      <div v-if="filteredCourses.length === 0" class="empty-tip">无相关课程</div>
      <div 
        v-for="course in filteredCourses" 
        :key="course.id" 
        class="course-item"
      >
        <div class="course-header">
          <span class="course-name">{{ course.name }}</span>
          <span class="course-id">{{ course.id }}</span>
        </div>
        <div class="course-info">
          <div>老师: {{ course.teacher_display }}</div>
          <div class="schedule-text" :title="course.raw_schedule">{{ course.raw_schedule }}</div>
        </div>
        <button @click="addCourse(course)">选课</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.course-list-container {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.search-bar {
  padding: 10px;
  border-bottom: 1px solid #eee;
  display: flex;
  justify-content: center;
}

.search-bar input {
  width: calc(100% - 20px); /* 减去一些边距 */
  max-width: 320px; /* 与课程项目宽度一致 */
  padding: 8px;
  border: 1px solid #ccc;
  border-radius: 4px;
}

.list-content {
  flex: 1;
  overflow-y: auto;
  padding: 10px;
}

.course-item {
  border: 1px solid #eee;
  padding: 10px;
  margin-bottom: 8px;
  border-radius: 4px;
  background: white;
  transition: box-shadow 0.2s;
}

.course-item:hover {
  box-shadow: 0 2px 5px rgba(0,0,0,0.1);
}

.course-header {
  display: flex;
  justify-content: space-between;
  font-weight: bold;
  margin-bottom: 5px;
}

.course-name {
  max-width: 70%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.course-id {
  color: #666;
  font-size: 0.9em;
}

.course-info {
  font-size: 0.85em;
  color: #555;
  margin-bottom: 8px;
}

.schedule-text {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: #777;
  font-size: 0.8em;
  margin-top: 3px;
}

.course-item button {
  background-color: #3f51b5;
  color: white;
  border: none;
  padding: 5px 10px;
  border-radius: 4px;
  cursor: pointer;
  width: 100%;
  font-size: 0.9em;
}

.course-item button:hover {
  background-color: #303f9f;
}

.empty-tip {
  text-align: center;
  color: #999;
  font-style: italic;
  padding: 20px 0;
}
</style>