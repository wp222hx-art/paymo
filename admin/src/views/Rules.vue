<template>
  <el-card shadow="never" class="page-card">
    <el-alert type="warning" :closable="false" show-icon style="margin-bottom: 14px">
      <b>清偿金 = 平台返佣 × 最终倍率</b>；最终倍率 = min(品类基础倍率 + 信用分加成, 全局上限)。品类规则挂在大类上，小类商品自动继承。只有「灰度」「生产」状态的规则生效，修改后对新订单即时生效，已下单订单保留快照。
      倍率 &gt; 1 的部分由合作银行以「让利」承担，资金背书始终 = 返佣。
    </el-alert>
    <div class="toolbar">
      <el-radio-group v-model="type">
        <el-radio-button value="">全部</el-radio-button>
        <el-radio-button v-for="(v, k) in RULE_TYPE" :key="k" :value="k">{{ v }}</el-radio-button>
      </el-radio-group>
      <div class="spacer" />
      <el-button type="primary" icon="Plus" @click="edit()">新增规则</el-button>
    </div>
    <el-table :data="shown" border>
      <el-table-column label="编码" prop="code" width="170" />
      <el-table-column label="类型" width="120"><template #default="{ row }">{{ RULE_TYPE[row.rule_type] }}</template></el-table-column>
      <el-table-column label="名称" prop="name" min-width="200" />
      <el-table-column label="适用范围" width="150"><template #default="{ row }">{{ row.rule_type === 'category' ? row.category_name : row.rule_type === 'credit_tier' ? `${row.credit_min} ~ ${row.credit_max}` : '全局' }}</template></el-table-column>
      <el-table-column label="值" width="80" align="right"><template #default="{ row }"><b>{{ row.rule_type === 'credit_tier' ? '+' : '×' }}{{ row.value }}</b></template></el-table-column>
      <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag :type="RULE_STATUS[row.status][1]" size="small">{{ RULE_STATUS[row.status][0] }}</el-tag></template></el-table-column>
      <el-table-column label="命中" prop="hit_count" width="80" align="right" />
      <el-table-column label="审批人" prop="approved_by" width="100" />
      <el-table-column label="操作" width="200">
        <template #default="{ row }">
          <el-button link type="primary" @click="edit(row)">编辑</el-button>
          <el-button v-if="row.status !== 2" link type="success" @click="setStatus(row, 2)">发布</el-button>
          <el-button v-if="row.status === 2" link type="warning" @click="setStatus(row, 3)">关闭</el-button>
          <el-popconfirm title="确定删除？" @confirm="remove(row)"><template #reference><el-button link type="danger">删除</el-button></template></el-popconfirm>
        </template>
      </el-table-column>
    </el-table>
  </el-card>

  <el-card shadow="never" header="倍率模拟（不同信用分用户的最终倍率）">
    <el-table :data="sim.rows" border size="small">
      <el-table-column label="分类" prop="category" />
      <el-table-column v-for="s in sim.scores" :key="s" :label="`信用分 ${s}`" align="center"><template #default="{ row }">×{{ row[s] }}</template></el-table-column>
    </el-table>
  </el-card>

  <el-dialog v-model="visible" :title="form.id ? '编辑规则' : '新增规则'" width="480px">
    <el-form label-width="100px">
      <el-form-item label="类型"><el-select v-model="form.rule_type" :disabled="!!form.id"><el-option v-for="(v, k) in RULE_TYPE" :key="k" :label="v" :value="k" /></el-select></el-form-item>
      <el-form-item label="名称"><el-input v-model="form.name" maxlength="60" /></el-form-item>
      <el-form-item v-if="form.rule_type === 'category'" label="分类"><el-select v-model="form.category_id"><el-option v-for="c in cats" :key="c.id" :label="c.name" :value="c.id" /></el-select></el-form-item>
      <template v-if="form.rule_type === 'credit_tier'">
        <el-form-item label="信用分下限"><el-input-number v-model="form.credit_min" :min="0" :max="1000" /></el-form-item>
        <el-form-item label="信用分上限"><el-input-number v-model="form.credit_max" :min="0" :max="1000" /></el-form-item>
      </template>
      <el-form-item :label="form.rule_type === 'credit_tier' ? '加成值' : '倍率'"><el-input-number v-model="form.value" :min="0" :max="20" :step="0.5" :precision="1" /></el-form-item>
      <el-form-item label="状态"><el-radio-group v-model="form.status"><el-radio v-for="(v, k) in RULE_STATUS" :key="k" :value="Number(k)">{{ v[0] }}</el-radio></el-radio-group></el-form-item>
    </el-form>
    <template #footer><el-button @click="visible = false">取消</el-button><el-button type="primary" @click="save">保存</el-button></template>
  </el-dialog>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { RULE_STATUS, RULE_TYPE, del, get, post, put } from '../api';

const list = ref([]);
const cats = ref([]);
const sim = ref({ rows: [], scores: [] });
const type = ref('');
const shown = computed(() => list.value.filter((r) => !type.value || r.rule_type === type.value));
const load = async () => {
  list.value = await get('/offset-rules');
  sim.value = await get('/offset-rules/simulate');
};
onMounted(async () => { cats.value = await get('/categories'); load(); });

const visible = ref(false);
const form = ref({});
const edit = (row) => { form.value = row ? { ...row } : { rule_type: 'category', name: '', category_id: cats.value[0]?.id, credit_min: 600, credit_max: 649, value: 3, status: 0 }; visible.value = true; };
const save = async () => {
  form.value.id ? await put(`/offset-rules/${form.value.id}`, form.value) : await post('/offset-rules', form.value);
  ElMessage.success('已保存');
  visible.value = false;
  load();
};
const setStatus = async (row, status) => { await put(`/offset-rules/${row.id}`, { status }); ElMessage.success('已更新'); load(); };
const remove = async (row) => { await del(`/offset-rules/${row.id}`); ElMessage.success('已删除'); load(); };
</script>
