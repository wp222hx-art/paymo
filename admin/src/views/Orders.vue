<template>
  <el-card shadow="never">
    <el-tabs v-model="q.status" @tab-change="reload">
      <el-tab-pane label="全部" name="" />
      <el-tab-pane v-for="(v, k) in ORDER_STATUS" :key="k" :label="v[0]" :name="String(k)" />
    </el-tabs>
    <div class="toolbar">
      <el-input v-model="q.keyword" placeholder="订单号 / 昵称 / 手机号" clearable style="width: 240px" @keyup.enter="reload" @clear="reload" />
      <el-button icon="Search" @click="reload">查询</el-button>
    </div>
    <el-table :data="list" border>
      <el-table-column label="订单号" prop="order_no" width="200" />
      <el-table-column label="用户" width="130"><template #default="{ row }">{{ row.nickname }}<div class="muted">{{ row.mobile }}</div></template></el-table-column>
      <el-table-column label="商品" min-width="220"><template #default="{ row }"><div v-for="i in row.items" :key="i.id">{{ i.emoji }} {{ i.name }} × {{ i.qty }}</div></template></el-table-column>
      <el-table-column label="实付" width="110" align="right"><template #default="{ row }"><span class="num">{{ money(row.pay_amount) }}</span></template></el-table-column>
      <el-table-column label="返佣 → 清偿金" width="150" align="right"><template #default="{ row }"><span class="num">{{ money(row.commission_amount) }}</span><div class="dp num">{{ dp(row.dp_amount) }}</div></template></el-table-column>
      <el-table-column label="状态" width="100"><template #default="{ row }"><el-tag :type="ORDER_STATUS[row.status][1]" size="small">{{ row.status_label }}</el-tag></template></el-table-column>
      <el-table-column label="清偿金" width="90"><template #default="{ row }"><el-tag v-if="row.commission_status != null" :type="COMMISSION_STATUS[row.commission_status][1]" size="small">{{ row.commission_status_label }}</el-tag></template></el-table-column>
      <el-table-column label="下单时间" width="170"><template #default="{ row }">{{ dt(row.created_at) }}</template></el-table-column>
      <el-table-column label="操作" width="170" fixed="right">
        <template #default="{ row }">
          <el-button link type="primary" @click="open(row)">详情</el-button>
          <el-button v-if="row.status === 20" link type="warning" @click="ship(row)">发货</el-button>
          <el-button v-if="row.status === 60" link type="danger" @click="open(row)">审核退款</el-button>
        </template>
      </el-table-column>
    </el-table>
    <el-pagination style="margin-top: 14px" layout="total, prev, pager, next" :total="total" v-model:current-page="q.page" :page-size="q.size" @change="load" />
  </el-card>

  <el-drawer v-model="drawer" size="620px" :title="cur ? `订单 ${cur.order_no}` : ''">
    <template v-if="cur">
      <el-descriptions :column="2" border size="small">
        <el-descriptions-item label="状态"><el-tag :type="ORDER_STATUS[cur.status][1]">{{ cur.status_label }}</el-tag></el-descriptions-item>
        <el-descriptions-item label="用户">{{ cur.user.nickname }}（信用分 {{ cur.user.credit_score }}）</el-descriptions-item>
        <el-descriptions-item label="商品金额">{{ money(cur.goods_amount) }}</el-descriptions-item>
        <el-descriptions-item label="运费">{{ money(cur.freight_amount) }}</el-descriptions-item>
        <el-descriptions-item label="实付">{{ money(cur.pay_amount) }}</el-descriptions-item>
        <el-descriptions-item label="支付方式">{{ cur.pay_channel || '-' }}</el-descriptions-item>
        <el-descriptions-item label="平台返佣">{{ money(cur.commission_amount) }}</el-descriptions-item>
        <el-descriptions-item label="清偿金"><span class="dp">{{ dp(cur.dp_amount) }}</span> · {{ cur.commission_status_label }}</el-descriptions-item>
        <el-descriptions-item label="收货信息" :span="2">{{ cur.address ? `${cur.address.name} ${cur.address.phone} ${cur.address.region} ${cur.address.detail}` : '虚拟商品 / 到店核销' }}</el-descriptions-item>
        <el-descriptions-item label="物流" :span="2">{{ cur.express_company ? `${cur.express_company} ${cur.express_no}` : '-' }}</el-descriptions-item>
        <el-descriptions-item v-if="cur.refund_reason" label="退款原因" :span="2">{{ cur.refund_reason }}</el-descriptions-item>
        <el-descriptions-item v-if="cur.remark" label="备注" :span="2">{{ cur.remark }}</el-descriptions-item>
      </el-descriptions>

      <h4>商品明细（返还倍率快照）</h4>
      <el-table :data="cur.items" size="small" border>
        <el-table-column label="商品"><template #default="{ row }">{{ row.emoji }} {{ row.name }} × {{ row.qty }}</template></el-table-column>
        <el-table-column label="小计" width="90"><template #default="{ row }">{{ money(row.subtotal) }}</template></el-table-column>
        <el-table-column label="佣金" width="90"><template #default="{ row }">{{ money(row.commission) }}</template></el-table-column>
        <el-table-column label="倍率" width="60" prop="multiplier" />
        <el-table-column label="积分" width="100"><template #default="{ row }"><el-tooltip :content="row.rule_snapshot"><span class="dp">{{ dp(row.dp_amount) }}</span></el-tooltip></template></el-table-column>
      </el-table>

      <h4>复式记账分录</h4>
      <el-table :data="cur.ledger" size="small" border>
        <el-table-column label="账户" prop="account" />
        <el-table-column label="借/贷" width="60" prop="direction" />
        <el-table-column label="金额" width="100"><template #default="{ row }">{{ money(row.amount) }}</template></el-table-column>
        <el-table-column label="业务" width="140" prop="biz_type" />
      </el-table>

      <div style="margin-top: 20px; display: flex; gap: 10px">
        <el-button v-if="cur.status === 20" type="warning" @click="ship(cur)">发货</el-button>
        <template v-if="cur.status === 60">
          <el-button type="danger" @click="refund(true)">同意退款（原路退回，清偿金失效）</el-button>
          <el-button @click="refund(false)">驳回</el-button>
        </template>
      </div>
    </template>
  </el-drawer>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { COMMISSION_STATUS, ORDER_STATUS, dp, dt, get, money, post } from '../api';

const emit = defineEmits(['changed']);
const list = ref([]);
const total = ref(0);
const q = reactive({ page: 1, size: 20, status: '', keyword: '' });
const load = async () => {
  const qs = new URLSearchParams(Object.entries(q).filter(([, v]) => v !== '' && v != null)).toString();
  const r = await get(`/orders?${qs}`);
  list.value = r.list;
  total.value = r.total;
};
const reload = () => { q.page = 1; load(); };
onMounted(load);

const drawer = ref(false);
const cur = ref(null);
const open = async (row) => { cur.value = await get(`/orders/${row.id}`); drawer.value = true; };
const refreshAll = async () => { await load(); if (drawer.value && cur.value) cur.value = await get(`/orders/${cur.value.id}`); emit('changed'); };

const ship = async (row) => {
  const { value } = await ElMessageBox.prompt('格式：物流公司 运单号（虚拟商品可留空）', `发货 ${row.order_no}`, { inputPlaceholder: '顺丰 SF1234567890', inputValue: '' });
  const [company, no] = (value || '').trim().split(/\s+/);
  await post(`/orders/${row.id}/ship`, { express_company: company || '', express_no: no || '' });
  ElMessage.success('已发货');
  refreshAll();
};
const refund = async (approve) => {
  let reason;
  if (!approve) ({ value: reason } = await ElMessageBox.prompt('驳回原因', '驳回退款', { inputValue: '商品已使用，不符合退款条件' }));
  else await ElMessageBox.confirm(`确认退款 ${money(cur.value.pay_amount)}？本单清偿金将失效。`, '同意退款');
  await post(`/orders/${cur.value.id}/refund-review`, { approve, reason });
  ElMessage.success('已处理');
  refreshAll();
};
</script>
