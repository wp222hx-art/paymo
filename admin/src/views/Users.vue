<template>
  <el-card shadow="never">
    <div class="toolbar">
      <el-input v-model="kw" placeholder="昵称 / 手机号 / 演示ID" clearable style="width: 240px" @keyup.enter="load" @clear="load" />
      <el-button icon="Search" @click="load">查询</el-button>
    </div>
    <el-table :data="list" border>
      <el-table-column label="ID" prop="id" width="60" />
      <el-table-column label="演示ID" prop="ext_id" width="90" />
      <el-table-column label="昵称" prop="nickname" width="120" />
      <el-table-column label="手机号" prop="mobile" width="130" />
      <el-table-column label="信用分" prop="credit_score" width="80" />
      <el-table-column label="钱包" width="120" align="right"><template #default="{ row }">{{ money(row.wallet_balance) }}</template></el-table-column>
      <el-table-column label="可用清偿金" width="130" align="right"><template #default="{ row }"><span class="dp">{{ dp(row.dp_available) }}</span></template></el-table-column>
      <el-table-column label="待清偿账单" width="130" align="right"><template #default="{ row }">{{ money(row.debt_outstanding) }}</template></el-table-column>
      <el-table-column label="订单" prop="order_count" width="70" />
      <el-table-column label="状态" width="80"><template #default="{ row }"><el-tag :type="row.status === 1 ? 'success' : 'danger'" size="small">{{ row.status === 1 ? '正常' : '冻结' }}</el-tag></template></el-table-column>
      <el-table-column label="操作" width="220" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="open(row)">详情</el-button>
          <el-button link type="warning" @click="grant(row)">补发清偿金</el-button>
          <el-button link :type="row.status === 1 ? 'danger' : 'success'" @click="toggle(row)">{{ row.status === 1 ? '冻结' : '解冻' }}</el-button>
        </template>
      </el-table-column>
    </el-table>
  </el-card>

  <el-drawer v-model="drawer" size="640px" :title="cur ? `${cur.user.nickname} · 信用分 ${cur.user.credit_score}` : ''">
    <template v-if="cur">
      <div class="toolbar"><span>调整信用分</span><el-input-number v-model="credit" :min="300" :max="1000" size="small" /><el-button size="small" @click="saveCredit">保存</el-button><span class="muted">信用分影响返还倍率加成</span></div>
      <h4>待清偿账单</h4>
      <el-table :data="cur.debts" size="small" border>
        <el-table-column label="银行" prop="creditor" />
        <el-table-column label="本金" width="110"><template #default="{ row }">{{ money(row.principal) }}</template></el-table-column>
        <el-table-column label="已清偿" width="110"><template #default="{ row }">{{ money(row.cleared) }}</template></el-table-column>
        <el-table-column label="剩余" width="110"><template #default="{ row }">{{ money(row.outstanding) }}</template></el-table-column>
      </el-table>
      <h4>清偿金批次</h4>
      <el-table :data="cur.batches" size="small" border>
        <el-table-column label="来源" prop="title" min-width="200" />
        <el-table-column label="面值" width="100"><template #default="{ row }">{{ dp(row.face_value) }}</template></el-table-column>
        <el-table-column label="背书" width="90"><template #default="{ row }">{{ money(row.cash_backed) }}</template></el-table-column>
        <el-table-column label="已用" width="100"><template #default="{ row }">{{ dp(row.consumed) }}</template></el-table-column>
      </el-table>
    </template>
  </el-drawer>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { dp, get, money, patch, post } from '../api';

const list = ref([]);
const kw = ref('');
const load = async () => { list.value = await get(`/users?keyword=${encodeURIComponent(kw.value)}`); };
onMounted(load);
const drawer = ref(false);
const cur = ref(null);
const credit = ref(600);
const open = async (row) => { cur.value = await get(`/users/${row.id}`); credit.value = cur.value.user.credit_score; drawer.value = true; };
const saveCredit = async () => { await patch(`/users/${cur.value.user.id}`, { credit_score: credit.value }); ElMessage.success('已保存'); load(); };
const toggle = async (row) => { await patch(`/users/${row.id}`, { status: row.status === 1 ? 2 : 1 }); ElMessage.success('已更新'); load(); };
const grant = async (row) => {
  const { value } = await ElMessageBox.prompt('格式：清偿金 资金背书 原因（背书 ≤ 清偿金，从平台营销费用列支）', `给 ${row.nickname} 补发清偿金`, { inputValue: '50 50 售后补偿' });
  const [points, cash, ...reason] = value.trim().split(/\s+/);
  await post(`/users/${row.id}/grant-dp`, { points: Number(points), cash_backed: Number(cash), reason: reason.join(' ') || '运营补发' });
  ElMessage.success('已补发');
  load();
};
</script>
