<template>
  <el-tabs v-model="tab" type="border-card">
    <el-tab-pane label="偿清证明" name="cert">
      <el-table :data="certs" border>
        <el-table-column label="证明编号" prop="cert_no" width="220" />
        <el-table-column label="用户" prop="nickname" width="100" />
        <el-table-column label="银行" prop="bank_name" />
        <el-table-column label="账户" prop="case_no" width="170" />
        <el-table-column label="原待清偿" width="120" align="right"><template #default="{ row }">{{ money(row.principal) }}</template></el-table-column>
        <el-table-column label="资金划转" width="110" align="right"><template #default="{ row }">{{ money(row.cash_paid) }}</template></el-table-column>
        <el-table-column label="银行让利" width="110" align="right"><template #default="{ row }">{{ money(row.reduction) }}</template></el-table-column>
        <el-table-column label="签发" prop="issued_by" width="140" />
        <el-table-column label="签发时间" width="170"><template #default="{ row }">{{ dt(row.issued_at) }}</template></el-table-column>
      </el-table>
    </el-tab-pane>
    <el-tab-pane label="银行回函" name="letters">
      <el-table :data="letters" border>
        <el-table-column type="expand"><template #default="{ row }"><p style="padding: 6px 30px; line-height: 1.9">{{ row.body }}</p></template></el-table-column>
        <el-table-column label="类型" width="110"><template #default="{ row }"><el-tag size="small" :type="LETTER_KIND[row.kind]?.[1]">{{ LETTER_KIND[row.kind]?.[0] }}</el-tag></template></el-table-column>
        <el-table-column label="标题" prop="title" width="160" />
        <el-table-column label="用户" prop="nickname" width="100" />
        <el-table-column label="银行" prop="bank_name" />
        <el-table-column label="回函编号" prop="ref_no" width="200" />
        <el-table-column label="已读" width="70"><template #default="{ row }">{{ row.read ? '是' : '否' }}</template></el-table-column>
        <el-table-column label="时间" width="170"><template #default="{ row }">{{ dt(row.created_at) }}</template></el-table-column>
      </el-table>
    </el-tab-pane>
    <el-tab-pane label="银行账单查询记录（模拟银行侧）" name="accounts">
      <el-alert type="info" :closable="false" style="margin-bottom: 12px">用户在 App 输入手机号查询时，模拟银行网关返回的账单（演示手机号 13800001001/13800001002 为预置数据，其他手机号按规则稳定生成）。正式上线时替换为银行开放接口 / 征信授权查询。</el-alert>
      <el-table :data="accounts" border>
        <el-table-column label="手机号" prop="mobile" width="130" />
        <el-table-column label="银行" prop="bank_name" width="140" />
        <el-table-column label="产品" prop="product" width="90" />
        <el-table-column label="账户" prop="account_no" />
        <el-table-column label="本金" width="110" align="right"><template #default="{ row }">{{ money(row.principal) }}</template></el-table-column>
        <el-table-column label="利息" width="100" align="right"><template #default="{ row }">{{ money(row.interest) }}</template></el-table-column>
        <el-table-column label="逾期天数" prop="overdue_days" width="90" />
        <el-table-column label="是否已接入" width="100"><template #default="{ row }"><el-tag size="small" :type="row.imported_case_id ? 'success' : 'info'">{{ row.imported_case_id ? '已接入' : '未接入' }}</el-tag></template></el-table-column>
      </el-table>
    </el-tab-pane>
  </el-tabs>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { LETTER_KIND, dt, get, money } from '../api';

const tab = ref('cert');
const certs = ref([]);
const letters = ref([]);
const accounts = ref([]);
onMounted(async () => {
  [certs.value, letters.value, accounts.value] = await Promise.all([get('/certificates'), get('/bank-letters'), get('/bank-accounts')]);
});
</script>
