<template>
  <el-card shadow="never">
    <div class="toolbar">
      <el-select v-model="q.category_id" placeholder="全部分类" clearable style="width: 140px" @change="reload">
        <el-option v-for="c in cats" :key="c.id" :label="(c.parent_id ? '　└ ' : '') + c.name" :value="c.id" />
      </el-select>
      <el-select v-model="q.status" placeholder="全部状态" clearable style="width: 110px" @change="reload">
        <el-option label="上架" :value="1" /><el-option label="下架" :value="0" />
      </el-select>
      <el-input v-model="q.keyword" placeholder="名称 / 商家" clearable style="width: 200px" @keyup.enter="reload" @clear="reload" />
      <el-button icon="Search" @click="reload">查询</el-button>
      <div class="spacer" />
      <el-button :disabled="!sel.length" @click="batch(1)">批量上架</el-button>
      <el-button :disabled="!sel.length" @click="batch(0)">批量下架</el-button>
      <el-button type="primary" icon="Plus" @click="edit()">新增商品</el-button>
    </div>
    <el-table :data="list" border @selection-change="(v) => (sel = v)">
      <el-table-column type="selection" width="40" />
      <el-table-column label="商品" min-width="260">
        <template #default="{ row }">
          <div style="display: flex; gap: 10px; align-items: center">
            <el-image v-if="row.image" :src="row.image" style="width: 52px; height: 52px; border-radius: 6px; flex: none" fit="cover" />
            <div><div>{{ row.emoji }} {{ row.name }}</div><div class="muted">{{ row.merchant }} · {{ row.category_name }}</div></div>
          </div>
        </template>
      </el-table-column>
      <el-table-column label="售价" width="100" align="right"><template #default="{ row }"><span class="num">{{ money(row.price) }}</span></template></el-table-column>
      <el-table-column label="返佣率" width="90" align="right"><template #default="{ row }">{{ row.commission_rate }}%</template></el-table-column>
      <el-table-column label="单件返佣" width="100" align="right"><template #default="{ row }"><span class="num">{{ money(row.commission) }}</span></template></el-table-column>
      <el-table-column label="基础返还" width="130" align="right">
        <template #default="{ row }"><el-tooltip :content="`返佣 × 品类倍率 ${row.base_multiplier}（信用加成另计）`"><span class="dp num">{{ dp(row.base_dp) }}</span></el-tooltip></template>
      </el-table-column>
      <el-table-column label="库存" width="80" align="right"><template #default="{ row }"><span :style="{ color: row.stock < 20 ? '#dc2626' : '' }">{{ row.stock }}</span></template></el-table-column>
      <el-table-column label="销量" prop="sales" width="70" align="right" />
      <el-table-column label="状态" width="80"><template #default="{ row }"><el-tag :type="row.status ? 'success' : 'info'" size="small">{{ row.status ? '上架' : '下架' }}</el-tag></template></el-table-column>
      <el-table-column label="操作" width="140" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="edit(row)">编辑</el-button>
          <el-popconfirm title="删除后不可恢复，有订单的商品请改为下架" @confirm="remove(row)"><template #reference><el-button link type="danger">删除</el-button></template></el-popconfirm>
        </template>
      </el-table-column>
    </el-table>
    <el-pagination style="margin-top: 14px" layout="total, prev, pager, next, sizes" :total="total" v-model:current-page="q.page" v-model:page-size="q.size" @change="load" />
  </el-card>

  <el-dialog v-model="visible" :title="form.id ? '编辑商品' : '新增商品'" width="640px">
    <el-form label-width="90px">
      <el-form-item label="分类"><el-select v-model="form.category_id"><el-option v-for="c in cats.filter((x) => x.parent_id)" :key="c.id" :label="`${c.parent_name} / ${c.name}`" :value="c.id" /></el-select></el-form-item>
      <el-form-item label="名称"><el-input v-model="form.name" maxlength="60" /></el-form-item>
      <el-form-item label="副标题"><el-input v-model="form.subtitle" maxlength="100" /></el-form-item>
      <el-form-item label="商家/品牌"><el-input v-model="form.merchant" maxlength="40" /></el-form-item>
      <el-form-item label="图标"><el-input v-model="form.emoji" style="width: 100px" /></el-form-item>
      <el-form-item label="主图"><ImageUpload v-model="form.image" /></el-form-item>
      <el-row>
        <el-col :span="12"><el-form-item label="售价"><el-input-number v-model="form.price" :min="0.01" :precision="2" :step="1" /></el-form-item></el-col>
        <el-col :span="12"><el-form-item label="划线价"><el-input-number v-model="form.original_price" :min="0" :precision="2" /></el-form-item></el-col>
      </el-row>
      <el-row>
        <el-col :span="12"><el-form-item label="返佣率 %"><el-input-number v-model="form.commission_rate" :min="0" :max="90" :precision="2" /></el-form-item></el-col>
        <el-col :span="12"><el-form-item label="库存"><el-input-number v-model="form.stock" :min="0" /></el-form-item></el-col>
      </el-row>
      <el-form-item label="返还预估">
        <span>单件返佣 <b>{{ money((form.price * form.commission_rate) / 100) }}</b> · 按品类倍率可返清偿金 <b class="dp">{{ dp(((form.price * form.commission_rate) / 100) * catMultiplier) }}</b>（信用加成另计）</span>
      </el-form-item>
      <el-form-item label="排序"><el-input-number v-model="form.sort" :min="0" /></el-form-item>
      <el-form-item label="详情"><el-input v-model="form.description" type="textarea" :rows="4" maxlength="2000" /></el-form-item>
      <el-form-item label="上架"><el-switch v-model="form.status" :active-value="1" :inactive-value="0" /></el-form-item>
    </el-form>
    <template #footer><el-button @click="visible = false">取消</el-button><el-button type="primary" @click="save">保存</el-button></template>
  </el-dialog>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { del, dp, get, money, post, put } from '../api';
import ImageUpload from './ImageUpload.vue';

const cats = ref([]);
const rules = ref([]);
const list = ref([]);
const total = ref(0);
const sel = ref([]);
const q = reactive({ page: 1, size: 20, category_id: '', status: '', keyword: '' });
const load = async () => {
  const qs = new URLSearchParams(Object.entries(q).filter(([, v]) => v !== '' && v != null)).toString();
  const r = await get(`/products?${qs}`);
  list.value = r.list;
  total.value = r.total;
};
const reload = () => { q.page = 1; load(); };
onMounted(async () => {
  cats.value = await get('/categories');
  rules.value = await get('/offset-rules');
  load();
});
const catMultiplier = computed(() => {
  const c = cats.value.find((x) => x.id === form.value.category_id);
  const live = (id) => rules.value.find((r) => r.rule_type === 'category' && r.category_id === id && [1, 2].includes(r.status));
  return (live(form.value.category_id) || (c && live(c.parent_id)))?.value ?? 1;
});

const visible = ref(false);
const form = ref({});
const edit = async (row) => {
  form.value = row ? { ...(await get(`/products/${row.id}`)) } : { category_id: cats.value.find((c) => c.parent_id)?.id, name: '', subtitle: '', merchant: '新光云自营', emoji: '🛍️', image: '', price: 99, original_price: null, commission_rate: 10, stock: 100, sort: 0, description: '', status: 1 };
  visible.value = true;
};
const save = async () => {
  form.value.id ? await put(`/products/${form.value.id}`, form.value) : await post('/products', form.value);
  ElMessage.success('已保存');
  visible.value = false;
  load();
};
const remove = async (row) => { await del(`/products/${row.id}`); ElMessage.success('已删除'); load(); };
const batch = async (status) => { await post('/products/batch-status', { ids: sel.value.map((x) => x.id), status }); ElMessage.success('已更新'); load(); };
</script>
