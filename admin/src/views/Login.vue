<template>
  <div class="wrap">
    <el-card class="card">
      <h2>✦ 星光云 · 运营后台</h2>
      <p class="muted">商品 · 订单 · 清偿金 · 返还倍率 · 清偿处理 · 银行回函</p>
      <el-form @submit.prevent="login" label-position="top">
        <el-form-item label="用户名"><el-input v-model="f.username" autocomplete="username" /></el-form-item>
        <el-form-item label="密码"><el-input v-model="f.password" type="password" show-password autocomplete="current-password" @keyup.enter="login" /></el-form-item>
        <el-button type="primary" style="width: 100%" :loading="loading" @click="login">登录</el-button>
      </el-form>
      <p class="muted" style="margin-top: 14px">首次启动默认账号 admin / admin123（可用环境变量 ADMIN_PASSWORD 指定），登录后请立即修改密码。</p>
    </el-card>
  </div>
</template>

<script setup>
import { reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { post, setToken } from '../api';

const router = useRouter();
const f = reactive({ username: 'admin', password: '' });
const loading = ref(false);
const login = async () => {
  loading.value = true;
  try {
    const r = await post('/login', f);
    setToken(r.token);
    router.push('/dashboard');
  } finally {
    loading.value = false;
  }
};
</script>

<style scoped>
.wrap { height: 100%; display: flex; align-items: center; justify-content: center; background: linear-gradient(135deg, #081b40, #1e3f7f); }
.card { width: 380px; }
h2 { margin: 0 0 4px; color: #0f2a5f; }
</style>
