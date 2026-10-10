<template>
  <el-row :gutter="16">
    <el-col :span="12">
      <el-card shadow="never" header="交易与结算参数">
        <el-form label-width="150px">
          <el-form-item v-for="s in list" :key="s.key" :label="s.key">
            <el-input-number v-model="form[s.key]" :min="0" :precision="s.key.includes('fee') || s.key.includes('multiplier') ? 2 : 0" />
            <div class="muted" style="width: 100%">{{ s.label }}</div>
          </el-form-item>
          <el-form-item><el-button type="primary" @click="save">保存</el-button></el-form-item>
        </el-form>
      </el-card>
    </el-col>
    <el-col :span="12">
      <el-card shadow="never" header="操作日志（最近 300 条）">
        <el-table :data="logs" size="small" border max-height="560">
          <el-table-column label="时间" width="160"><template #default="{ row }">{{ dt(row.created_at) }}</template></el-table-column>
          <el-table-column label="管理员" prop="admin" width="80" />
          <el-table-column label="操作" prop="action" width="150" />
          <el-table-column label="对象" prop="target" />
        </el-table>
      </el-card>
    </el-col>
  </el-row>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { dt, get, put } from '../api';

const list = ref([]);
const logs = ref([]);
const form = reactive({});
const load = async () => {
  list.value = await get('/settings');
  for (const s of list.value) form[s.key] = Number(s.value);
  logs.value = await get('/logs');
};
onMounted(load);
const save = async () => { await put('/settings', form); ElMessage.success('已保存'); load(); };
</script>
