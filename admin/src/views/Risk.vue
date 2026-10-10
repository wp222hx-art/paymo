<template>
  <el-tabs v-model="tab" type="border-card" @tab-change="load">
    <el-tab-pane label="风险案件" name="cases">
      <el-radio-group v-model="caseStatus" @change="load" style="margin-bottom: 12px">
        <el-radio-button value="0">待处置</el-radio-button>
        <el-radio-button value="">全部</el-radio-button>
      </el-radio-group>
      <el-table :data="cases" border>
        <el-table-column label="时间" width="160"><template #default="{ row }">{{ dt(row.created_at) }}</template></el-table-column>
        <el-table-column label="规则" width="200"><template #default="{ row }">{{ row.rule_name }}<div class="muted">{{ row.rule_code }}</div></template></el-table-column>
        <el-table-column label="用户" width="110"><template #default="{ row }">{{ row.nickname || 'U' + row.user_id }}</template></el-table-column>
        <el-table-column label="场景" prop="scene" width="90" />
        <el-table-column label="详情" prop="detail" />
        <el-table-column label="分值" prop="score" width="70" />
        <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag size="small" :type="CASE_TYPE[row.status]">{{ CASE_LABEL[row.status] }}</el-tag></template></el-table-column>
        <el-table-column label="操作" width="190">
          <template #default="{ row }">
            <template v-if="row.status === 0">
              <el-button link type="success" @click="handle(row, 'pass')">放行</el-button>
              <el-button link type="warning" @click="handle(row, 'block')">拦截</el-button>
              <el-button link type="danger" @click="handle(row, 'freeze')">冻结账号</el-button>
            </template>
          </template>
        </el-table-column>
      </el-table>
    </el-tab-pane>
    <el-tab-pane label="提现审核" name="withdrawals">
      <el-table :data="withdrawals" border>
        <el-table-column label="单号" prop="withdraw_no" width="190" />
        <el-table-column label="用户" prop="nickname" width="100" />
        <el-table-column label="金额" width="110" align="right"><template #default="{ row }">{{ money(row.amount) }}</template></el-table-column>
        <el-table-column label="到账卡" width="170"><template #default="{ row }">{{ row.bank_name }} {{ row.card_mask }}</template></el-table-column>
        <el-table-column label="风险命中"><template #default="{ row }"><el-tag v-for="x in row.risk_hits" :key="x.code" size="small" type="warning" style="margin-right: 4px">{{ x.name }}</el-tag></template></el-table-column>
        <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag size="small">{{ row.status_label }}</el-tag></template></el-table-column>
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <template v-if="row.status === 10">
              <el-button link type="success" @click="wd(row, 'approve')">放款</el-button>
              <el-button link type="danger" @click="wd(row, 'reject')">驳回</el-button>
            </template>
          </template>
        </el-table-column>
      </el-table>
    </el-tab-pane>
    <el-tab-pane label="内容审核" name="posts">
      <div class="toolbar"><el-button type="primary" @click="settle">结算内容激励（现金 + 清偿金）</el-button></div>
      <el-table :data="posts" border>
        <el-table-column label="标题" prop="title" width="240" />
        <el-table-column label="作者" prop="author" width="100" />
        <el-table-column label="正文"><template #default="{ row }"><div style="white-space: pre-wrap; max-height: 80px; overflow: hidden">{{ row.body }}</div></template></el-table-column>
        <el-table-column label="互动" width="120"><template #default="{ row }">赞 {{ row.likes }} · 评 {{ row.comments }}</template></el-table-column>
        <el-table-column label="累计激励" width="100"><template #default="{ row }">{{ money(row.revenue) }}</template></el-table-column>
        <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag size="small" :type="POST_TYPE[row.status]">{{ row.status_label }}</el-tag></template></el-table-column>
        <el-table-column label="操作" width="180">
          <template #default="{ row }">
            <el-button v-if="row.status !== 1" link type="success" @click="mod(row, 'approve')">发布</el-button>
            <el-button v-if="row.status !== 2" link type="warning" @click="mod(row, 'feature')">精选</el-button>
            <el-button v-if="row.status !== 9" link type="danger" @click="mod(row, 'block')">拦截</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-tab-pane>
    <el-tab-pane label="风控规则" name="rules">
      <el-table :data="rules" border>
        <el-table-column label="编码" prop="code" width="150" />
        <el-table-column label="名称" prop="name" width="170" />
        <el-table-column label="场景" prop="scene" width="90" />
        <el-table-column label="说明" prop="description" />
        <el-table-column label="阈值" width="140"><template #default="{ row }"><el-input-number v-if="row.threshold != null" v-model="row.threshold" size="small" :min="0" @change="saveRule(row)" /></template></el-table-column>
        <el-table-column label="动作" width="130">
          <template #default="{ row }">
            <el-select v-model="row.action" size="small" @change="saveRule(row)">
              <el-option label="放行" value="pass" />
              <el-option label="人工复核" value="review" />
              <el-option label="拦截" value="block" />
            </el-select>
          </template>
        </el-table-column>
        <el-table-column label="命中" prop="hits" width="70" />
        <el-table-column label="启用" width="80"><template #default="{ row }"><el-switch :model-value="row.enabled === 1" @change="(v) => toggle(row, v)" /></template></el-table-column>
      </el-table>
    </el-tab-pane>
  </el-tabs>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { dt, get, money, post, put } from '../api';

const emit = defineEmits(['changed']);
const CASE_TYPE = ['warning', 'success', 'danger', 'danger'];
const CASE_LABEL = ['待处置', '已放行', '已拦截', '已冻结'];
const POST_TYPE = { 0: 'warning', 1: 'success', 2: 'danger', 9: 'info' };
const tab = ref('cases');
const caseStatus = ref('0');
const cases = ref([]);
const withdrawals = ref([]);
const posts = ref([]);
const rules = ref([]);
const load = async () => {
  if (tab.value === 'cases') cases.value = await get(`/risk/cases?status=${caseStatus.value}`);
  if (tab.value === 'withdrawals') withdrawals.value = await get('/withdrawals');
  if (tab.value === 'posts') posts.value = await get('/posts');
  if (tab.value === 'rules') rules.value = await get('/risk/rules');
};
onMounted(load);
const done = () => {
  ElMessage.success('已处理');
  load();
  emit('changed');
};
const handle = async (row, action) => {
  const { value } = await ElMessageBox.prompt('处置说明', '风险处置', { inputValue: action === 'pass' ? '核实无误' : '风控处置' });
  await post(`/risk/cases/${row.id}`, { action, note: value });
  done();
};
const wd = async (row, action) => {
  let note;
  if (action === 'reject') ({ value: note } = await ElMessageBox.prompt('驳回原因（资金退回用户钱包）', '驳回提现', { inputValue: '风控核实未通过' }));
  await post(`/withdrawals/${row.id}/${action}`, { note });
  done();
};
const mod = async (row, action) => {
  await post(`/posts/${row.id}/${action}`, { note: action === 'block' ? '违反社区规范' : undefined });
  done();
};
const settle = async () => {
  const r = await post('/posts/settle-revenue');
  ElMessage.success(`已结算 ${r.settled} 篇内容的激励`);
  load();
};
const saveRule = async (row) => {
  await put(`/risk/rules/${row.code}`, row);
  ElMessage.success('规则已更新');
};
const toggle = (row, v) => {
  row.enabled = v ? 1 : 0;
  saveRule(row);
};
</script>
