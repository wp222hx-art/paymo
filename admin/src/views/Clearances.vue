<template>
  <el-card shadow="never">
    <el-alert type="info" :closable="false" show-icon style="margin-bottom: 14px">
      清偿流程：用户提交清偿金 → <b>银行受理</b> → <b>资金划转</b>（从备付金划给银行，金额 = 资金背书）→ <b>核减</b>（银行按面值核减账单，差额为银行让利）。账单余额归零时自动出具《偿清证明》并发送偿清确认函。受理阶段可退回，清偿金原路返还。
    </el-alert>
    <div class="toolbar">
      <el-radio-group v-model="status" @change="load">
        <el-radio-button value="">全部</el-radio-button>
        <el-radio-button v-for="(v, k) in CLEAR_STATUS" :key="k" :value="String(k)">{{ v[0] }}</el-radio-button>
      </el-radio-group>
    </div>
    <el-table :data="list" border>
      <el-table-column type="expand">
        <template #default="{ row }">
          <el-timeline style="padding: 10px 30px">
            <el-timeline-item v-for="(e, i) in row.history" :key="i" :timestamp="`${dt(e.at)} · ${e.operator}`">{{ CLEAR_STATUS[e.status]?.[0] }} — {{ e.note }}</el-timeline-item>
          </el-timeline>
        </template>
      </el-table-column>
      <el-table-column label="清偿单号" prop="clearance_no" width="200" />
      <el-table-column label="用户" prop="nickname" width="100" />
      <el-table-column label="银行 / 账单" min-width="200"><template #default="{ row }">{{ row.creditor }}<div class="muted">{{ row.case_no }} · 剩余 {{ money(row.outstanding) }}</div></template></el-table-column>
      <el-table-column label="清偿金(核减额)" width="130" align="right"><template #default="{ row }"><span class="dp">{{ dp(row.points) }}</span></template></el-table-column>
      <el-table-column label="资金划转" width="110" align="right"><template #default="{ row }"><span class="ok">{{ money(row.cash_remitted) }}</span></template></el-table-column>
      <el-table-column label="银行让利" width="110" align="right"><template #default="{ row }">{{ money(row.reduction) }}</template></el-table-column>
      <el-table-column label="状态" width="110"><template #default="{ row }"><el-tag :type="CLEAR_STATUS[row.status][1]" size="small">{{ row.status_label }}</el-tag></template></el-table-column>
      <el-table-column label="提交时间" width="170"><template #default="{ row }">{{ dt(row.created_at) }}</template></el-table-column>
      <el-table-column label="操作" width="180" fixed="right">
        <template #default="{ row }">
          <el-button v-if="row.status === 10" link type="primary" @click="act(row, 'accept')">受理</el-button>
          <el-button v-if="row.status === 20" link type="primary" @click="act(row, 'remit')">确认划转</el-button>
          <el-button v-if="row.status === 30" link type="success" @click="act(row, 'write-off')">核减</el-button>
          <el-button v-if="[10, 20].includes(row.status)" link type="danger" @click="reject(row)">退回</el-button>
        </template>
      </el-table-column>
    </el-table>
  </el-card>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { CLEAR_STATUS, dp, dt, get, money, post } from '../api';

const emit = defineEmits(['changed']);
const list = ref([]);
const status = ref('');
const load = async () => { list.value = await get(`/clearances${status.value ? `?status=${status.value}` : ''}`); };
onMounted(load);
const LABEL = { accept: '受理', remit: '确认划转', 'write-off': '核减' };
const act = async (row, action) => {
  let body = {};
  if (action === 'remit') {
    const { value } = await ElMessageBox.prompt(`确认已从备付金向「${row.creditor}」划转 ${money(row.cash_remitted)}，请填写银行流水号（可留空自动生成）`, '确认划转', { inputValue: '' });
    body = { bank_ref: value || undefined };
  } else {
    await ElMessageBox.confirm(action === 'write-off' ? `将为用户核减账单 ${dp(row.points)}，不可撤销；余额归零会自动出具偿清证明。` : `受理清偿单 ${row.clearance_no}？`, LABEL[action]);
  }
  await post(`/clearances/${row.id}/${action}`, body);
  ElMessage.success(`${LABEL[action]}成功`);
  load();
  emit('changed');
};
const reject = async (row) => {
  const { value } = await ElMessageBox.prompt('退回原因（清偿金将返还用户）', '退回清偿单', { inputValue: '资料不全' });
  await post(`/clearances/${row.id}/reject`, { reason: value });
  ElMessage.success('已退回');
  load();
  emit('changed');
};
</script>
