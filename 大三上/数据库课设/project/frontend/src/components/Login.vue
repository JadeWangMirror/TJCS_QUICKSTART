<script setup lang="ts">
import { ref } from 'vue';
import axios from 'axios';

const email = ref('');
const password = ref('');
const loading = ref(false);
const fullName = ref('');
const regEmail = ref('');
const regPassword = ref('');
const showRegister = ref(false);

const emit = defineEmits(['login']);

const handleLogin = async () => {
  if (!email.value || !password.value) { alert('请填写所有字段'); return; }
  loading.value = true;
  try {
    const response = await axios.post('http://localhost:5000/api/login', { email: email.value, password: password.value });
    localStorage.setItem('token', response.data.token);
    localStorage.setItem('user', JSON.stringify(response.data.user));
    emit('login', response.data.user);
  } catch (error: any) { alert(error.response?.data?.error || '登录失败'); } finally { loading.value = false; }
};

const handleRegister = async () => {
  if (!fullName.value || !regEmail.value || !regPassword.value) { alert('请填写所有字段'); return; }
  loading.value = true;
  try {
    const response = await axios.post('http://localhost:5000/api/register', { full_name: fullName.value, email: regEmail.value, password: regPassword.value });
    localStorage.setItem('token', response.data.token);
    localStorage.setItem('user', JSON.stringify(response.data.user));
    emit('login', response.data.user);
  } catch (error: any) { alert(error.response?.data?.error || '注册失败'); } finally { loading.value = false; }
};
</script>

<template>
  <div class="login-page">
    <div class="login-card">
      <div class="card-visual">
        <div class="visual-content">
          <h2>SmartSchedule</h2>
          <p>智能排课 · 轻松管理</p>
        </div>
      </div>
      <div class="card-form">
        <Transition name="fade" mode="out-in">
          <div v-if="!showRegister" key="login">
            <h3 class="form-title">欢迎回来</h3>
            <form @submit.prevent="handleLogin">
              <div class="form-item">
                <label>邮箱地址</label>
                <input v-model="email" type="email" placeholder="email@example.com" />
              </div>
              <div class="form-item">
                <label>访问密码</label>
                <input v-model="password" type="password" placeholder="••••••••" />
              </div>
              <button class="submit-btn" :disabled="loading">
                <span v-if="!loading">登录系统</span>
                <div v-else class="loader"></div>
              </button>
            </form>
            <p class="footer-tip">新用户？<a @click="showRegister = true">创建账户</a></p>
          </div>
          <div v-else key="register">
            <h3 class="form-title">加入我们</h3>
            <form @submit.prevent="handleRegister">
              <div class="form-item">
                <label>真实姓名</label>
                <input v-model="fullName" type="text" placeholder="张三" />
              </div>
              <div class="form-item">
                <label>电子邮箱</label>
                <input v-model="regEmail" type="email" placeholder="yourname@site.com" />
              </div>
              <div class="form-item">
                <label>设置密码</label>
                <input v-model="regPassword" type="password" placeholder="至少6位数字" />
              </div>
              <button class="submit-btn" :disabled="loading">确认注册</button>
            </form>
            <p class="footer-tip">已有账户？<a @click="showRegister = false">立即登录</a></p>
          </div>
        </Transition>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-page { height: 100vh; display: flex; align-items: center; justify-content: center; background: #f0f2f5; }
.login-card { width: 800px; height: 500px; background: white; border-radius: 20px; display: flex; overflow: hidden; box-shadow: 0 20px 40px rgba(0,0,0,0.1); }
.card-visual { flex: 1; background: linear-gradient(135deg, #6366f1 0%, #a855f7 100%); display: flex; align-items: center; justify-content: center; color: white; padding: 40px; }
.visual-content h2 { font-size: 32px; margin-bottom: 12px; }
.card-form { flex: 1.2; padding: 48px; display: flex; flex-direction: column; justify-content: center; }
.form-title { font-size: 24px; margin-bottom: 32px; color: #1e293b; }
.form-item { margin-bottom: 20px; }
.form-item label { display: block; font-size: 13px; font-weight: 600; color: #64748b; margin-bottom: 8px; }
.form-item input { width: 100%; padding: 12px; border: 1px solid #e2e8f0; border-radius: 10px; font-size: 14px; }
.submit-btn { width: 100%; padding: 14px; background: #6366f1; color: white; border: none; border-radius: 10px; cursor: pointer; font-weight: 700; transition: 0.3s; margin-top: 12px; }
.submit-btn:hover { background: #4f46e5; transform: translateY(-2px); }
.footer-tip { text-align: center; margin-top: 24px; font-size: 14px; color: #64748b; }
.footer-tip a { color: #6366f1; font-weight: 600; cursor: pointer; }
</style>