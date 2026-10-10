<template>
  <el-row :gutter="16" class="page-card">
    <el-col :span="6" v-for="c in cards" :key="c.t"><el-card shadow="never"><div class="muted">{{ c.t }}</div><div style="font-size: 22px; font-weight: 800; color: #0f2a5f">{{ c.v }}</div></el-card></el-col>
  </el-row>
  <el-card shadow="never">
    <el-tabs v-model="tab" @tab-change="load">
      <el-tab-pane label="任务审核" name="audit" />
      <el-tab-pane label="全部任务" name="tasks" />
      <el-tab-pane label="申诉仲裁" name="disputes" />
      <el-tab-pane label="全部任务单" name="orders" />
    </el-tabs>
    <el-alert v-if="tab === 'audit'" type="info" :closable="false" style="margin-bottom: 12px">新任务无敏感词时自动上架；命中「刷单 / 引流 / 垫付」等词进入人工审核。驳回后押金原路退回商家。</el-alert>
    <el-table v-if="tab === 'audit' || tab === 'tasks'" :data="tasks" border>
      <el-table-column label="编号" prop="task_no" width="110" />
      <el-table-column label="任务" min-width="240"><template #default="{ row }">{{ row.type_icon }} {{ row.title }}<div class="muted">{{ row.publisher_name }} · {{ row.type_name }}{{ row.city ? ' · ' + row.city : ' · 线上' }}</div></template></el-table-column>
      <el-table-column label="报酬" width="90" align="right"><template #default="{ row }">{{ money(row.reward) }}</template></el-table-column>
      <el-table-column label="现金/清偿金" width="110"><template #default="{ row }">{{ row.cash_pct }}% / {{ row.clear_pct }}%</template></el-table-column>
      <el-table-column label="完成/报名/名额" width="130"><template #default="{ row }">{{ row.done }} / {{ row.taken }} / {{ row.quota }}</template></el-table-column>
      <el-table-column label="托管押金余额" width="120" align="right"><template #default="{ row }">{{ money(row.deposit_left) }}</template></el-table-column>
      <el-table-column label="状态" width="90"><template #default="{ row }"><el-tag size="small" :type="{ 1: 'warning', 2: 'success', 8: 'danger' }[row.status] || 'info'">{{ row.status_label }}</el-tag></template></el-table-column>
      <el-table-column label="操作" width="150">
        <template #default="{ row }">
          <template v-if="row.status === 1">
            <el-button link type="success" @click="audit(row, true)">通过</el-button>
            <el-button link type="danger" @click="audit(row, false)">驳回</el-button>
          </template>
        </template>
      </el-table-column>
    </el-table>
    <el-table v-else :data="orders" border>
      <el-table-column type="expand"><template #default="{ row }"><div style="padding: 8px 30px; line-height: 1.8">
        <p><b>交付：</b>{{ row.submission_text }} <a v-if="row.submission_link" :href="row.submission_link" target="_blank">{{ row.submission_link }}</a></p>
        <p v-if="row.ai_report"><b>AI 初审：</b>{{ row.ai_score }} 分 {{ (row.ai_report.reasons || []).join('；') }}</p>
        <p v-if="row.review_note"><b>商家：</b>{{ row.review_note }}</p>
        <p v-if="row.dispute_reason"><b>申诉：</b>{{ row.dispute_reason }}</p>
        <el-timeline><el-timeline-item v-for="(h, i) in row.history" :key="i" :timestamp="dt(h.at) + ' · ' + h.operator">{{ h.note }}</el-timeline-item></el-timeline>
      </div></template></el-table-column>
      <el-table-column label="单号" prop="order_no" width="190" />
      <el-table-column label="任务" min-width="200"><template #default="{ row }">{{ row.task?.title }}<div class="muted">{{ row.task?.publisher_name }}</div></template></el-table-column>
      <el-table-column label="接单人" width="100"><template #default="{ row }">{{ row.worker?.nickname }}</template></el-table-column>
      <el-table-column label="AI" width="70"><template #default="{ row }">{{ row.ai_score ?? '-' }}</template></el-table-column>
      <el-table-column label="结算（现金 / 清偿金）" width="170"><template #default="{ row }"><span v-if="row.status === 80">{{ money(row.cash_amount) }} / <span class="dp">{{ money(row.clear_amount) }}</span></span></template></el-table-column>
      <el-table-column label="状态" width="110"><template #default="{ row }"><el-tag size="small">{{ row.status_label }}</el-tag></template></el-table-column>
      <el-table-column label="操作" width="160">
        <template #default="{ row }">
          <template v-if="row.status === 55">
            <el-button link type="success" @click="arb(row, true)">支持用户</el-button>
            <el-button link type="danger" @click="arb(row, false)">维持驳回</el-button>
          </template>
        </template>
      </el-table-column>
    </el-table>
  </el-card>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { dt, get, money, post } from '../api';

const emit = defineEmits(['changed']);
const tab = ref('audit');
const tasks = ref([]);
const orders = ref([]);
const stats = ref(null);
const load = async () => {
  stats.value = await get('/labor/stats');
  if (tab.value === 'audit') tasks.value = await get('/labor/tasks?status=1');
  if (tab.value === 'tasks') tasks.value = await get('/labor/tasks');
  if (tab.value === 'disputes') orders.value = await get('/labor/orders?status=55');
  if (tab.value === 'orders') orders.value = await get('/labor/orders');
};
onMounted(load);
const cards = computed(() => {
  const s = stats.value;
  if (!s) return [];
  return [
    { t: '招募中任务 / 待审核', v: `${s.tasks.live || 0} / ${s.tasks.audit || 0}` },
    { t: '托管押金', v: money(s.tasks.escrow) },
    { t: '已结算单数 / 申诉中', v: `${s.orders.settled || 0} / ${s.orders.disputes || 0}` },
    { t: '平台服务费 · 发放现金 · 清偿金', v: `${money(s.orders.fee)} · ${money(s.orders.cash)} · ${money(s.orders.clear)}` },
  ];
});
const audit = async (row, approve) => {
  let reason;
  if (!approve) ({ value: reason } = await ElMessageBox.prompt('驳回原因（押金将退回商家）', '驳回任务', { inputValue: '疑似引流 / 违规' }));
  await post(`/labor/tasks/${row.id}/audit`, { approve, reason });
  ElMessage.success('已处理');
  load();
  emit('changed');
};
const arb = async (row, approve) => {
  const { value } = await ElMessageBox.prompt(approve ? '仲裁说明（将从押金结算给用户）' : '维持驳回的理由', '平台仲裁', { inputValue: approve ? '交付符合任务要求' : '交付不符合要求' });
  await post(`/labor/orders/${row.id}/arbitrate`, { approve, note: value });
  ElMessage.success('已仲裁');
  load();
  emit('changed');
};
</script>
