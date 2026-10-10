<template>
  <div v-if="d">
    <el-row :gutter="16" class="page-card">
      <el-col :span="6" v-for="c in cards" :key="c.t">
        <el-card shadow="never"><div class="muted">{{ c.t }}</div><div class="big num">{{ c.v }}</div><div class="muted">{{ c.s }}</div></el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16" class="page-card">
      <el-col :span="16">
        <el-card shadow="never" header="近 14 天 GMV / 返佣">
          <div class="chart">
            <div v-for="t in d.trend" :key="t.date" class="bar-col" :title="`${t.date} 订单 ${t.orders} · GMV ${money(t.gmv)} · 佣金 ${money(t.commission)}`">
              <div class="bar" :style="{ height: (t.gmv / maxGmv) * 160 + 'px' }"><div class="bar2" :style="{ height: (t.commission / maxGmv) * 160 + 'px' }" /></div>
              <div class="muted">{{ t.date }}</div>
            </div>
          </div>
          <div class="muted">蓝色 = GMV，橙色 = 平台返佣（返佣 × 倍率 → 用户清偿金）</div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never" header="待办">
          <div class="todo" @click="$router.push('/orders')">待发货订单 <b>{{ d.todo.to_ship }}</b></div>
          <div class="todo" @click="$router.push('/orders')">退款待审核 <b>{{ d.todo.refunding }}</b></div>
          <div class="todo" @click="$router.push('/commissions')">到期待到账清偿金 <b>{{ d.todo.commissions_due }}</b></div>
          <div class="todo" @click="$router.push('/clearances')">处理中清偿单 <b>{{ d.todo.clearances }}</b></div>
          <div class="todo" @click="$router.push('/labor')">任务待审核 / 申诉 <b>{{ d.todo.task_audit }} / {{ d.todo.disputes }}</b></div>
          <div class="todo" @click="$router.push('/risk')">提现待审 / 风险案件 / 内容待审 <b>{{ d.todo.withdrawals }} / {{ d.todo.risk_cases }} / {{ d.todo.posts }}</b></div>
          <div class="todo" @click="$router.push('/products')">低库存商品 (&lt;20) <b>{{ d.products.low_stock || 0 }}</b></div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="16">
      <el-col :span="8">
        <el-card shadow="never" header="平台返佣">
          <p>待收货<span class="fr num">{{ money(d.commission.estimated) }}</span></p>
          <p>保障期中<span class="fr num">{{ money(d.commission.pending) }}</span></p>
          <p>已转为清偿金<span class="fr num ok">{{ money(d.commission.settled) }}</span></p>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never" header="清偿金">
          <p>累计发放<span class="fr num dp">{{ dp(d.dp.issued) }}</span></p>
          <p>已用于清偿<span class="fr num">{{ dp(d.dp.consumed) }}</span></p>
          <p>备付金（未用清偿金的资金背书）<span class="fr num ok">{{ money(d.dp.reserve) }}</span></p>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card shadow="never" header="清偿成效">
          <p>接入账单总额<span class="fr num">{{ money(d.debt.principal) }}</span></p>
          <p>已清偿<span class="fr num ok">{{ money(d.debt.cleared) }}</span></p>
          <p>已偿清笔数 / 偿清证明<span class="fr num">{{ d.debt.settled_cases || 0 }} / {{ d.debt.cases }} · {{ d.certificates }} 份</span></p>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue';
import { dp, get, money } from '../api';

const d = ref(null);
onMounted(async () => { d.value = await get('/dashboard'); });
const maxGmv = computed(() => Math.max(1, ...d.value.trend.map((t) => t.gmv)));
const cards = computed(() => [
  { t: '今日 GMV', v: money(d.value.today.gmv), s: `${d.value.today.orders} 笔 · 佣金 ${money(d.value.today.commission)}` },
  { t: '累计 GMV', v: money(d.value.total.gmv), s: `${d.value.total.orders} 笔已支付订单` },
  { t: '累计返佣', v: money(d.value.total.commission), s: `返还清偿金 ${dp(d.value.total.dp)}` },
  { t: '用户 / 在售商品', v: `${d.value.users} / ${d.value.products.online || 0}`, s: `共 ${d.value.products.total} 个商品` },
]);
</script>

<style scoped>
.big { font-size: 24px; font-weight: 800; color: #0f2a5f; margin: 6px 0; }
.chart { display: flex; align-items: flex-end; gap: 6px; height: 190px; }
.bar-col { flex: 1; text-align: center; font-size: 10px; }
.bar { background: #2563eb33; border-top: 2px solid #2563eb; position: relative; min-height: 2px; display: flex; align-items: flex-end; }
.bar2 { background: #ff7a59; width: 100%; }
.todo { padding: 9px 0; border-bottom: 1px dashed #e5e7eb; cursor: pointer; }
.todo b { float: right; color: #dc2626; }
.fr { float: right; }
p { margin: 8px 0; }
</style>
