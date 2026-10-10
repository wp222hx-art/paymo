<template>
  <el-row :gutter="16">
    <el-col :span="9">
      <el-card shadow="never" header="科目余额（借 − 贷）">
        <el-alert :type="d.check?.balanced ? 'success' : 'error'" :closable="false" style="margin-bottom: 10px">
          借方合计 {{ money(d.check?.d) }} · 贷方合计 {{ money(d.check?.c) }} · {{ d.check?.balanced ? '借贷平衡 ✓' : '借贷不平衡！' }}
        </el-alert>
        <el-table :data="d.balances" size="small" border max-height="600">
          <el-table-column label="账户" prop="account" />
          <el-table-column label="余额" width="120" align="right"><template #default="{ row }"><span class="num">{{ money(row.balance) }}</span></template></el-table-column>
        </el-table>
      </el-card>
    </el-col>
    <el-col :span="15">
      <el-card shadow="never" header="分录明细（最近 500 条）">
        <div class="toolbar">
          <el-input v-model="kw" placeholder="业务单号 / 账户" clearable style="width: 240px" @keyup.enter="load" @clear="load" />
          <el-button icon="Search" @click="load">查询</el-button>
        </div>
        <el-table :data="d.list" size="small" border max-height="600">
          <el-table-column label="时间" width="160"><template #default="{ row }">{{ dt(row.created_at) }}</template></el-table-column>
          <el-table-column label="业务" prop="biz_type" width="130" />
          <el-table-column label="单号" prop="biz_ref" width="200" />
          <el-table-column label="账户" prop="account" min-width="180" />
          <el-table-column label="借/贷" prop="direction" width="60" />
          <el-table-column label="金额" width="100" align="right"><template #default="{ row }">{{ money(row.amount) }}</template></el-table-column>
        </el-table>
      </el-card>
    </el-col>
  </el-row>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { dt, get, money } from '../api';

const d = ref({});
const kw = ref('');
const load = async () => { d.value = await get(`/ledger?keyword=${encodeURIComponent(kw.value)}`); };
onMounted(load);
</script>
