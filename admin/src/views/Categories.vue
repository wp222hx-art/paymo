<template>
  <el-card shadow="never">
    <div class="toolbar">
      <el-button type="primary" icon="Plus" @click="edit()">新增分类</el-button>
      <span class="muted">大类决定「品类基础倍率」（在「返还倍率规则」中配置），小类自动继承</span>
    </div>
    <el-table :data="list" border>
      <el-table-column label="图片" width="90"><template #default="{ row }"><el-image v-if="row.image" :src="row.image" style="width: 56px; height: 40px" fit="cover" /></template></el-table-column>
      <el-table-column label="图标" prop="icon" width="70" />
      <el-table-column label="名称"><template #default="{ row }"><span :style="{ paddingLeft: row.parent_id ? '22px' : 0, fontWeight: row.parent_id ? 400 : 700 }">{{ row.parent_id ? '└ ' : '' }}{{ row.name }}</span></template></el-table-column>
      <el-table-column label="层级" width="110"><template #default="{ row }"><el-tag size="small" :type="row.parent_id ? 'info' : 'warning'">{{ row.parent_id ? '小类 · ' + row.parent_name : '大类 · ' + row.child_count + ' 个小类' }}</el-tag></template></el-table-column>
      <el-table-column label="商品数" prop="product_count" width="90" />
      <el-table-column label="排序" prop="sort" width="80" />
      <el-table-column label="状态" width="100"><template #default="{ row }"><el-switch :model-value="row.status === 1" @change="(v) => save({ ...row, status: v ? 1 : 0 })" /></template></el-table-column>
      <el-table-column label="操作" width="160">
        <template #default="{ row }">
          <el-button link type="primary" @click="edit(row)">编辑</el-button>
          <el-popconfirm title="确定删除？" @confirm="remove(row)"><template #reference><el-button link type="danger">删除</el-button></template></el-popconfirm>
        </template>
      </el-table-column>
    </el-table>
  </el-card>

  <el-dialog v-model="visible" :title="form.id ? '编辑分类' : '新增分类'" width="460px">
    <el-form label-width="80px">
      <el-form-item label="上级分类"><el-select v-model="form.parent_id" clearable placeholder="不选 = 大类"><el-option v-for="c in list.filter((x) => !x.parent_id && x.id !== form.id)" :key="c.id" :label="c.name" :value="c.id" /></el-select></el-form-item>
      <el-form-item label="名称"><el-input v-model="form.name" maxlength="20" /></el-form-item>
      <el-form-item label="图标"><el-input v-model="form.icon" placeholder="Emoji，如 🍜" /></el-form-item>
      <el-form-item label="图片"><ImageUpload v-model="form.image" /></el-form-item>
      <el-form-item label="排序"><el-input-number v-model="form.sort" :min="0" /></el-form-item>
    </el-form>
    <template #footer><el-button @click="visible = false">取消</el-button><el-button type="primary" @click="save(form, true)">保存</el-button></template>
  </el-dialog>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { del, get, post, put } from '../api';
import ImageUpload from './ImageUpload.vue';

const list = ref([]);
const visible = ref(false);
const form = ref({});
const load = async () => { list.value = await get('/categories'); };
onMounted(load);
const edit = (row) => { form.value = row ? { ...row } : { name: '', icon: '🛍️', image: '', sort: 0, status: 1, parent_id: null }; visible.value = true; };
const save = async (f, close) => {
  f.id ? await put(`/categories/${f.id}`, f) : await post('/categories', f);
  ElMessage.success('已保存');
  if (close) visible.value = false;
  load();
};
const remove = async (row) => { await del(`/categories/${row.id}`); ElMessage.success('已删除'); load(); };
</script>
