<template>
  <el-container style="height: 100%">
    <el-aside width="210px" class="aside">
      <div class="brand">✦ 星光云 · 运营后台</div>
      <el-menu :default-active="$route.path" router background-color="#0f2a5f" text-color="#c9d4ea" active-text-color="#f5b942">
        <el-menu-item v-for="r in menus" :key="r.path" :index="'/' + r.path">
          <el-icon><component :is="r.meta.icon" /></el-icon>
          <span>{{ r.meta.title }}</span>
          <el-badge v-if="badge(r.path)" :value="badge(r.path)" class="mbadge" />
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="header">
        <span class="title">{{ $route.meta.title }}</span>
        <div class="spacer" />
        <el-button size="small" @click="runJobs" :loading="jobLoading">执行定时任务</el-button>
        <a href="/" target="_blank"><el-button size="small" type="primary" plain>打开用户端 App</el-button></a>
        <el-dropdown @command="onCmd">
          <span class="user">{{ admin?.name || '管理员' }} <el-icon><ArrowDown /></el-icon></span>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="pwd">修改密码</el-dropdown-item>
              <el-dropdown-item command="logout" divided>退出登录</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </el-header>
      <el-main><router-view @changed="loadTodo" /></el-main>
    </el-container>

    <el-dialog v-model="pwdVisible" title="修改密码" width="380px">
      <el-form label-width="80px">
        <el-form-item label="原密码"><el-input v-model="pwd.old_password" type="password" show-password /></el-form-item>
        <el-form-item label="新密码"><el-input v-model="pwd.new_password" type="password" show-password placeholder="至少 8 位" /></el-form-item>
      </el-form>
      <template #footer><el-button @click="pwdVisible = false">取消</el-button><el-button type="primary" @click="savePwd">保存</el-button></template>
    </el-dialog>
  </el-container>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { get, post, setToken } from './api';

const router = useRouter();
const menus = computed(() => router.options.routes.find((r) => r.path === '/').children);
const admin = ref(null);
const todo = ref({});
const badge = (p) => ({ orders: todo.value.to_ship + todo.value.refunding, clearances: todo.value.clearances, commissions: todo.value.commissions_due, labor: (todo.value.task_audit || 0) + (todo.value.disputes || 0), risk: (todo.value.withdrawals || 0) + (todo.value.risk_cases || 0) + (todo.value.posts || 0) })[p] || 0;

const loadTodo = async () => {
  try { todo.value = (await get('/dashboard', { silent: true })).todo; } catch { /* ignore */ }
};
let timer;
onMounted(async () => {
  admin.value = await get('/me');
  loadTodo();
  timer = setInterval(loadTodo, 30000);
});
onUnmounted(() => clearInterval(timer));

const jobLoading = ref(false);
const runJobs = async () => {
  jobLoading.value = true;
  try {
    const r = await post('/jobs/run');
    ElMessage.success(`超时关单 ${r.cancelled} · 自动收货 ${r.confirmed} · 清偿金到账 ${r.settled} · 任务自动验收 ${r.labor?.autoPass ?? 0}`);
    loadTodo();
  } finally {
    jobLoading.value = false;
  }
};

const pwdVisible = ref(false);
const pwd = reactive({ old_password: '', new_password: '' });
const savePwd = async () => {
  await post('/password', pwd);
  ElMessage.success('密码已修改');
  pwdVisible.value = false;
};
const onCmd = (c) => {
  if (c === 'pwd') pwdVisible.value = true;
  if (c === 'logout') { setToken(null); router.push('/login'); }
};
</script>

<style scoped>
.aside { background: #0f2a5f; }
.brand { color: #f5b942; font-weight: 800; font-size: 17px; padding: 20px 18px; letter-spacing: 1px; }
.el-menu { border-right: none; }
.mbadge { margin-left: 8px; }
.mbadge :deep(.el-badge__content) { border: none; }
.header { background: #fff; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #e5e7eb; }
.title { font-size: 17px; font-weight: 700; color: #14213d; }
.spacer { flex: 1; }
.user { cursor: pointer; display: flex; align-items: center; gap: 4px; margin-left: 8px; }
</style>
