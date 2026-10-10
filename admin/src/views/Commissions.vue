<template>
  <el-card shadow="never">
    <el-alert type="info" :closable="false" show-icon style="margin-bottom: 14px">
      清偿金生命周期：用户支付 → <b>待收货</b> → 确认收货 → <b>保障期中</b>（售后保障期，系统设置可调）→ 到期自动 <b>到账</b>，按「平台返佣 × 返还倍率」发放清偿金（资金背书 = 返佣）。退款则 <b>失效</b>。
    </el-alert>
    <div class="toolbar">
      <el-radio-group v-model="status" @change="load">
        <el-radio-button value="">全部</el-radio-button>
        <el-radio-button v-for="(v, k) in COMMISSION_STATUS" :key="k" :value="String(k)">{{ v[0] }}</el-radio-button>
      </el-radio-group>
      <div class="spacer" />
      <el-button type="primary" @click="settleDue">一键到账全部到期清偿金</el-button>
    </div>
    <el-table :data="list" border>
      <el-table-column label="订单号" prop="order_no" width="200" />
      <el-table-column label="用户" prop="nickname" width="110" />
      <el-table-column label="实付" width="110" align="right"><template #default="{ row }">{{ money(row.pay_amount) }}</template></el-table-column>
      <el-table-column label="平台返佣(资金背书)" width="130" align="right"><template #default="{ row }">{{ money(row.commission) }}</template></el-table-column>
      <el-table-column label="清偿金" width="130" align="right"><template #default="{ row }"><span class="dp">{{ dp(row.dp_amount) }}</span></template></el-table-column>
      <el-table-column label="状态" width="100"><template #default="{ row }"><el-tag :type="COMMISSION_STATUS[row.status][1]" size="small">{{ row.status_label }}</el-tag></template></el-table-column>
      <el-table-column label="可结算时间" width="170"><template #default="{ row }">{{ dt(row.settle_at) }} <el-tag v-if="row.due" size="small" type="danger">到期</el-tag></template></el-table-column>
      <el-table-column label="到账时间" width="170"><template #default="{ row }">{{ dt(row.settled_at) }}</template></el-table-column>
      <el-table-column label="操作" width="110">
        <template #default="{ row }">
          <el-popconfirm v-if="row.status === 1" title="跳过保障期，立即到账？到账后订单不可退款" @confirm="settle(row)"><template #reference><el-button link type="primary">提前到账</el-button></template></el-popconfirm>
        </template>
      </el-table-column>
    </el-table>
  </el-card>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { ElMessage } from 'element-plus';
import { COMMISSION_STATUS, dp, dt, get, money, post } from '../api';

const emit = defineEmits(['changed']);
const list = ref([]);
const status = ref('');
const load = async () => { list.value = (await get(`/commissions${status.value !== '' ? `?status=${status.value}` : ''}`)).list; };
onMounted(load);
const settle = async (row) => { const r = await post(`/commissions/${row.id}/settle`); ElMessage.success(`已到账 ${dp(r.dp_amount)}`); load(); emit('changed'); };
const settleDue = async () => { const r = await post('/commissions/settle-due'); ElMessage.success(`已到账 ${r.settled} 笔`); load(); emit('changed'); };
</script>
