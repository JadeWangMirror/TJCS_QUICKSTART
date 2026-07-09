<template>
  <div class="ai-advisor-wrapper">
    <div class="ai-advisor-container">
      <div class="chat-header">
        <div class="header-left">
          <h3>选课规划能手</h3>
          <div class="status-indicator" :class="{ online: isConnected }"></div>
        </div>
        <span class="status-text">{{ isConnected ? '在线' : '连接中...' }}</span>
      </div>
      
      <div class="chat-messages" ref="messagesContainer">
        <div 
          v-for="(msg, index) in messages" 
          :key="index" 
          :class="['message', msg.sender]"
        >
          <div class="message-content">
            <div class="message-bubble" :class="{ user: msg.sender === 'user' }">
              <div v-if="msg.sender === 'ai'" class="ai-message-content" v-html="renderMarkdown(msg.text)"></div>
              <div v-else class="user-message-content">{{ msg.text }}</div>
            </div>
            <div class="message-time">{{ formatTime(msg.timestamp) }}</div>
          </div>
        </div>
        
        <div v-if="isLoading" class="message ai">
          <div class="message-content">
            <div class="message-bubble ai">
              <div class="typing-indicator">
                <div class="dot"></div>
                <div class="dot"></div>
                <div class="dot"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="chat-input-area">
        <input 
          v-model="userInput" 
          @keyup.enter="sendMessage"
          placeholder="询问选课建议..." 
          :disabled="isLoading"
          class="chat-input"
        />
        <button 
          @click="sendMessage" 
          :disabled="isLoading || !userInput.trim()"
          class="send-button"
        >
          发送
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, nextTick, watch } from 'vue';

// 接口定义
interface Course {
  id: string;
  name: string;
  // 根据你的 types.ts 补充
}

interface Message {
  id: string;
  text: string;
  sender: 'user' | 'ai';
  timestamp: Date;
}

interface Session {
  day: number;
  day_str: string;
  start: number;
  end: number;
  weeks: string;
  location: string;
  teacher: string;
}

interface CourseWithSessions extends Course {
  sessions: Session[];
  raw_schedule: string;
  teacher_display: string;
}

const props = defineProps<{
  courses: CourseWithSessions[];
  selectedCourses: CourseWithSessions[];
  userId: string;
}>();

const messages = ref<Message[]>([]);
const userInput = ref('');
const isLoading = ref(false);
const isConnected = ref(false);
const messagesContainer = ref<HTMLElement | null>(null);
const sessionId = ref('');

// 监听用户ID变化，加载对应的历史记录
watch(() => props.userId, (newUserId) => {
  if (newUserId) {
    sessionId.value = `ai_session_${newUserId}`;
    loadHistory();
  }
});

// 获取当前用户课表的上下文信息
const getUserTimetableContext = () => {
  if (!props.selectedCourses || props.selectedCourses.length === 0) {
    return "当前没有已选课程";
  }

  let context = `当前已选课程 (${props.selectedCourses.length} 门):\n`;
  props.selectedCourses.forEach((course, index) => {
    if (course.sessions && course.sessions.length > 0) {
      const session = course.sessions[0]; // 取第一个时间段
      context += `${index + 1}. ${course.name}\n   时间: ${session.day_str} ${session.start}-${session.end}节\n   地点: ${session.location}\n   教师: ${course.teacher_display}\n\n`;
    } else {
      context += `${index + 1}. ${course.name}\n   时间: 未指定\n\n`;
    }
  });

  // 检查时间冲突
  const conflicts = detectTimeConflicts(props.selectedCourses);
  if (conflicts.length > 0) {
    context += `检测到时间冲突 (${conflicts.length} 处):\n`;
    conflicts.forEach((conflict, index) => {
      context += `${index + 1}. ${conflict.course1.name} 与 ${conflict.course2.name} 在 ${conflict.day_str} ${conflict.start_time}-${conflict.end_time} 时间冲突\n`;
    });
  } else {
    context += "当前课表没有时间冲突\n";
  }

  // 分析课表密度
  const densityAnalysis = analyzeTimetableDensity(props.selectedCourses);
  context += `课表密度分析:\n`;
  Object.entries(densityAnalysis).forEach(([day, courses]) => {
    if (courses.length > 0) {
      context += `  ${day}: ${courses.length} 节课\n`;
    }
  });

  return context;
};

// 检测时间冲突
const detectTimeConflicts = (courses: CourseWithSessions[]) => {
  const conflicts: { course1: CourseWithSessions, course2: CourseWithSessions, day_str: string, start_time: number, end_time: number }[] = [];
  
  for (let i = 0; i < courses.length; i++) {
    for (let j = i + 1; j < courses.length; j++) {
      const course1 = courses[i];
      const course2 = courses[j];
      
      // 检查每对课程的时间段
      for (const session1 of course1.sessions) {
        for (const session2 of course2.sessions) {
          // 检查是否在同一天且时间段重叠
          if (session1.day === session2.day) {
            if (
              (session1.start <= session2.end && session1.end >= session2.start) ||
              (session2.start <= session1.end && session2.end >= session1.start)
            ) {
              conflicts.push({
                course1,
                course2,
                day_str: session1.day_str,
                start_time: Math.max(session1.start, session2.start),
                end_time: Math.min(session1.end, session2.end)
              });
            }
          }
        }
      }
    }
  }
  
  return conflicts;
};

// 分析课表密度
const analyzeTimetableDensity = (courses: CourseWithSessions[]) => {
  const density: { [key: string]: CourseWithSessions[] } = {
    '星期一': [],
    '星期二': [],
    '星期三': [],
    '星期四': [],
    '星期五': [],
    '星期六': [],
    '星期日': []
  };
  
  courses.forEach(course => {
    course.sessions.forEach(session => {
      density[session.day_str].push(course);
    });
  });
  
  return density;
};

// Markdown 渲染逻辑
const renderMarkdown = (text: string) => {
  let escapedText = text
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#x27;');
  
  escapedText = escapedText.replace(/\*\*(.*?)\*\*|__(.*?)__/g, '<strong>$1$2</strong>');
  escapedText = escapedText.replace(/\*(.*?)\*|_(.*?)_/g, '<em>$1$2</em>');
  escapedText = escapedText.replace(/`(.*?)`/g, '<code class="inline-code">$1</code>');
  escapedText = escapedText.replace(/```([\s\S]*?)```/g, '<pre class="code-block"><code>$1</code></pre>');
  escapedText = escapedText.replace(/^### (.*$)/gm, '<h3>$1</h3>');
  escapedText = escapedText.replace(/^## (.*$)/gm, '<h2>$1</h2>');
  escapedText = escapedText.replace(/^# (.*$)/gm, '<h1>$1</h1>');
  escapedText = escapedText.replace(/^\s*\*\s(.*)$/gm, '<li class="list-item">$1</li>');
  escapedText = escapedText.replace(/(<li class="list-item">.*<\/li>)/gs, '<ul class="list-unordered">$1</ul>');
  escapedText = escapedText.replace(/^\s*\d+\.\s(.*)$/gm, '<li class="list-item">$1</li>');
  escapedText = escapedText.replace(/(<li class="list-item">.*<\/li>)/gs, '<ol class="list-ordered">$1</ol>');
  escapedText = escapedText.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank">$1</a>');
  escapedText = escapedText.replace(/\n/g, '<br>');
  
  return escapedText;
};

const loadHistory = async () => {
  // 从数据库获取历史记录
  try {
    const response = await fetch('http://localhost:5000/api/ai-history', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        userId: props.userId,
        sessionId: sessionId.value
      })
    });
    
    const data = await response.json();
    
    if (data.messages && data.messages.length > 0) {
      // 将数据库中的消息转换为前端格式
      messages.value = data.messages.map((msg: any, index: number) => ({
        id: `db-${index}`,
        text: msg.content,
        sender: msg.role === 'user' ? 'user' : 'ai',
        timestamp: new Date(msg.timestamp)
      }));
    } else {
      // 如果没有历史记录，显示欢迎消息
      messages.value = [{
        id: 'welcome',
        text: "您好！我是您的选课规划能手，我可以根据您的课表情况提供个性化的选课建议。",
        sender: 'ai',
        timestamp: new Date()
      }];
    }
  } catch (e) {
    console.error("加载历史记录失败:", e);
    messages.value = [{
      id: 'welcome',
      text: "您好！我是您的选课规划能手，我可以根据您的课表情况提供个性化的选课建议。",
      sender: 'ai',
      timestamp: new Date()
    }];
  }
};


const formatTime = (date: Date) => date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

const scrollToBottom = async () => {
  await nextTick();
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight;
  }
};

const sendMessage = async () => {
  if (!userInput.value.trim() || isLoading.value) return;
  
  const userMsg: Message = {
    id: Date.now().toString(),
    text: userInput.value,
    sender: 'user',
    timestamp: new Date()
  };
  
  messages.value.push(userMsg);
  const text = userInput.value;
  userInput.value = '';
  isLoading.value = true;
  scrollToBottom();
  
  try {
    // 获取用户课表上下文
    const timetableContext = getUserTimetableContext();
    
    const response = await fetch('http://localhost:5000/api/ai-advisor', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        message: text, 
        userId: props.userId, 
        courses: props.courses, 
        selectedCourses: props.selectedCourses,
        timetableContext: timetableContext,  // 添加课表上下文
        sessionId: sessionId.value  // 添加会话ID
      })
    });
    
    const data = await response.json();
    messages.value.push({
      id: (Date.now() + 1).toString(),
      text: data.reply,
      sender: 'ai',
      timestamp: new Date()
    });
  } catch (e) {
    messages.value.push({
      id: 'error',
      text: "连接失败，请检查网络。",
      sender: 'ai',
      timestamp: new Date()
    });
  } finally {
    isLoading.value = false;
    scrollToBottom();
  }
};

onMounted(() => {
  if (props.userId) {
    sessionId.value = `ai_session_${props.userId}`;
    loadHistory();
  }
  scrollToBottom();
  setTimeout(() => isConnected.value = true, 1000);
});
</script>

<style scoped>
/* 包裹层：确保撑满屏幕且不溢出 */
.ai-advisor-wrapper {
  height: 100vh;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: #f1f5f9;
  padding: 20px; /* 留出外边距，防止贴边 */
  box-sizing: border-box;
}

.ai-advisor-container {
  display: flex;
  flex-direction: column;
  width: 100%;
  max-width: 1200px;
  /* 关键修改：高度减去上下 padding 的值 */
  height: calc(100vh - 40px); 
  background: white;
  border-radius: 16px;
  overflow: hidden;
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
}

.chat-header {
  background: #fff;
  padding: 16px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #e2e8f0;
  flex-shrink: 0; /* 禁止头部压缩 */
}

.header-left {
  display: flex;
  align-items: center;
  gap: 10px;
}

.status-text {
  font-size: 0.75rem;
  color: #94a3b8;
}

.chat-header h3 {
  margin: 0;
  color: #1e293b;
  font-size: 1.1rem;
  font-weight: 600;
}

.status-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #cbd5e1;
}

.status-indicator.online {
  background: #10b981;
  box-shadow: 0 0 6px #10b981;
}

.chat-messages {
  flex: 1; /* 占据中间所有剩余空间 */
  padding: 20px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 16px;
  background: #f8fafc;
}

.message {
  display: flex;
  max-width: 85%;
}

.message.user {
  align-self: flex-end;
  flex-direction: row-reverse;
}

.message-bubble {
  padding: 12px 16px;
  border-radius: 18px;
  font-size: 0.95rem;
  line-height: 1.5;
}

.message.user .message-bubble {
  background: #3b82f6;
  color: white;
  border-bottom-right-radius: 4px;
}

.message.ai .message-bubble {
  background: white;
  border: 1px solid #e2e8f0;
  color: #1e293b;
  border-bottom-left-radius: 4px;
}

.message-time {
  font-size: 0.7rem;
  color: #94a3b8;
  margin-top: 4px;
}

.chat-input-area {
  padding: 20px;
  background: white;
  border-top: 1px solid #e2e8f0;
  display: flex;
  gap: 10px;
  flex-shrink: 0; /* 禁止底部压缩 */
}

.chat-input {
  flex: 1;
  padding: 12px 18px;
  border: 1px solid #e2e8f0;
  border-radius: 24px;
  outline: none;
  background: #f8fafc;
}

.chat-input:focus {
  border-color: #3b82f6;
  background: #fff;
}

.send-button {
  padding: 0 24px;
  background: #3b82f6;
  color: white;
  border: none;
  border-radius: 24px;
  cursor: pointer;
  font-weight: 600;
}

.send-button:disabled {
  background: #cbd5e1;
}

/* 消息内容内部样式渲染 */
.ai-message-content :deep(h1), .ai-message-content :deep(h2) { margin: 8px 0; }
.ai-message-content :deep(ul), .ai-message-content :deep(ol) { padding-left: 20px; }
.ai-message-content :deep(.inline-code) { background: #eee; padding: 2px 4px; border-radius: 4px; }

.typing-indicator { display: flex; gap: 4px; }
.dot { width: 6px; height: 6px; background: #cbd5e1; border-radius: 50%; animation: blink 1.4s infinite; }
@keyframes blink { 0%, 100% { opacity: 0.3; } 50% { opacity: 1; } }
</style>