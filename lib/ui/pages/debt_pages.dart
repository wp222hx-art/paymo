import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../../core/module_info.dart';
import '../widgets/module_widgets.dart';
import 'agent_pages.dart';
import 'debt_points_pages.dart';
import 'wallet_pages.dart';

class DebtCenterPage extends StatelessWidget {
  const DebtCenterPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final dp = s.myDebtProfile;
    final cases = s.myCases;
    return Scaffold(
      appBar: AppBar(title: const Text('债务中心 · D06 还债与账户域'), actions: [
        const InfoButton(Modules.debtCenter),
        IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: '导入债务', onPressed: () => _importSheet(context)),
      ]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (dp != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: XCard(
                margin: EdgeInsets.zero,
                gradient: XgColors.navyGradient,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('负债画像 U-102 · API-U-004（需支付密码）', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(fmtMoney(dp.totalDebt), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                    Text('总待还 · ${dp.debtCount} 笔 · 逾期总额 ${fmtMoney(dp.overdueAmount)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 14),
                    Row(children: [
                      _score('多头借贷指数', dp.multiBorrowIndex, invert: true),
                      _score('还款意愿分', dp.repaymentWillingness),
                      _score('还款能力分', dp.repaymentAbility),
                    ]),
                    const SizedBox(height: 12),
                    _bar('信用卡', dp.creditCard, dp.totalDebt, XgColors.gold),
                    _bar('消费金融', dp.consumerLoan, dp.totalDebt, XgColors.coral),
                    _bar('网贷', dp.p2p, dp.totalDebt, XgColors.violet),
                    _bar('银行贷款', dp.bankLoan, dp.totalDebt, XgColors.info),
                    if (dp.privateDebt > 0) _bar('民间借贷', dp.privateDebt, dp.totalDebt, XgColors.success),
                    const SizedBox(height: 8),
                    Text('月收入 ${fmtMoney(dp.monthlyIncome)}${dp.incomeVerified ? ' ✓ 已核实' : '（待核实）'} · 安全月供上限 ${fmtMoney(dp.monthlyIncome * 0.45)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.all(16),
              child: XCard(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  const Icon(Icons.folder_open_outlined, size: 40, color: XgColors.divider),
                  const SizedBox(height: 8),
                  const Text('该身份暂无负债档案', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('可手动录入或授权央行征信导入（需 L3 活体认证）', style: TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => _importSheet(context), child: const Text('导入债务')),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => openAgent(context, 'AG-01'), icon: const Text('🧭'), label: const Text('债务规划师', style: TextStyle(fontSize: 13)))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => openAgent(context, 'AG-05'), icon: const Text('🤝'), label: const Text('谈判专家', style: TextStyle(fontSize: 13)))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerPage())), icon: const Icon(Icons.menu_book_outlined, size: 16), label: const Text('复式账本', style: TextStyle(fontSize: 13)))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.sunrise,
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtPointsPage())),
              child: Row(children: [
                const Icon(Icons.token_outlined, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.myAvailablePoints.toStringAsFixed(1)} DP 可转交银行清缴', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  const Text('两条平债通道：还款计划（现金直付）+ 债务积分（银行核销）· 余额归零即出具结清证明', style: TextStyle(color: Colors.white70, fontSize: 10)),
                ])),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
          const SectionTitle('债务案件 DebtCase · API-R-003'),
          if (cases.isEmpty) const EmptyHint('暂无案件'),
          ...cases.map((c) => _CaseCard(c)),
        ],
      ),
    );
  }

  Widget _score(String l, double v, {bool invert = false}) {
    final good = invert ? v < 40 : v >= 70;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v.toStringAsFixed(1), style: TextStyle(color: good ? XgColors.gold : XgColors.coral, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }

  Widget _bar(String l, double v, double total, Color c) {
    if (v <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        SizedBox(width: 56, child: Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: total == 0 ? 0 : v / total, minHeight: 6, backgroundColor: Colors.white.withValues(alpha: 0.12), color: c))),
        const SizedBox(width: 8),
        SizedBox(width: 72, child: Text(fmtMoney(v), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 11))),
      ]),
    );
  }

  void _importSheet(BuildContext context) {
    final s = context.read<AppState>();
    final creditor = TextEditingController();
    final amount = TextEditingController();
    final overdue = TextEditingController(text: '0');
    DebtType type = DebtType.creditCard;
    String source = 'user_manual';
    bool consent = false;
    showXSheet(
      context,
      title: '导入债务 · API-R-001 / R-002',
      StatefulBuilder(
        builder: (ctx, setSt) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'user_manual', label: Text('手动录入')), ButtonSegment(value: 'pboc_credit', label: Text('央行征信导入'))],
              selected: {source},
              onSelectionChanged: (v) => setSt(() => source = v.first),
            ),
            const SizedBox(height: 12),
            if (source == 'pboc_credit') ...[
              XCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('合规校验节点 · 征信查询', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('需：KYC ≥ L3 活体 · Consent(scope=pboc_credit_query) 有效 · 查询原因合法。Consent 记录含 IP/设备指纹/页面快照，默认 1 年有效。', style: TextStyle(fontSize: 11, color: XgColors.textSecondary)),
                  CheckboxListTile(
                    value: consent,
                    onChanged: (v) => setSt(() => consent = v ?? false),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('我授权新光云向中国人民银行征信中心查询本人信用报告', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            TextField(controller: creditor, decoration: const InputDecoration(labelText: '债权机构', hintText: '如：浦发银行信用卡中心')),
            const SizedBox(height: 10),
            DropdownButtonFormField<DebtType>(
              initialValue: type,
              items: DebtType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
              onChanged: (v) => setSt(() => type = v!),
              decoration: const InputDecoration(labelText: '债务类型'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '待还金额（元）'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: overdue, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '逾期天数'))),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final r = await s.call('POST', '/v1/debt-cases/import/${source == 'pboc_credit' ? 'pboc' : 'manual'}', apiId: source == 'pboc_credit' ? 'API-R-001' : 'API-R-002', kycRequired: source == 'pboc_credit' ? 3 : 2, body: {
                  'source': source,
                  'consent': consent,
                  'creditor': creditor.text.trim().isEmpty ? (source == 'pboc_credit' ? '征信报告 · 浦发银行' : null) : creditor.text.trim(),
                  'debt_type': type.name,
                  'amount': double.tryParse(amount.text) ?? (source == 'pboc_credit' ? 18600 : 0),
                  'overdue_days': int.tryParse(overdue.text) ?? 0,
                });
                if (!ctx.mounted) return;
                showApiResult(ctx, r, successText: '案件 ${r.data?['case_id']} 已创建 · Webhook DEBT.CASE.IMPORTED');
                if (r.ok) Navigator.pop(ctx);
              },
              child: const Text('提交导入'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  final DebtCase c;
  const _CaseCard(this.c);
  @override
  Widget build(BuildContext context) {
    final negColor = c.negotiationStatus == 3 || c.negotiationStatus == 4 ? XgColors.success : (c.negotiationStatus == 5 ? XgColors.danger : (c.negotiationStatus == 0 ? XgColors.textSecondary : XgColors.warning));
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DebtCaseDetailPage(caseId: c.caseId))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(c.creditorName, style: const TextStyle(fontWeight: FontWeight.w700))),
            Tag(c.bucket, color: c.overdueDays > 90 ? XgColors.danger : (c.overdueDays > 0 ? XgColors.warning : XgColors.success)),
            const SizedBox(width: 4),
            Tag(c.negotiationLabel, color: negColor),
          ]),
          const SizedBox(height: 6),
          Text('${c.debtType.label} · ${c.caseNo} · 来源 ${c.importSource}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('待还余额', style: TextStyle(fontSize: 10, color: XgColors.textSecondary)), Text(fmtMoney(c.outstanding), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('本金 ${fmtMoney(c.principal)}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
              Text('利息 ${fmtMoney(c.interest)} · 罚息 ${fmtMoney(c.penalty)}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
              Text('逾期 ${c.overdueDays} 天', style: TextStyle(fontSize: 11, color: c.overdueDays > 0 ? XgColors.danger : XgColors.success)),
            ]),
          ]),
        ],
      ),
    );
  }
}

class DebtCaseDetailPage extends StatelessWidget {
  final String caseId;
  const DebtCaseDetailPage({super.key, required this.caseId});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.db.debtCases.firstWhere((c) => c.caseId == caseId);
    final plans = s.plansFor(caseId);
    final active = plans.where((p) => p.status == 3 || p.status == 4).firstOrNull;
    final candidates = plans.where((p) => p.status == 1 || p.status == 2).toList();
    final cert = s.certOf(caseId);
    final clearances = s.myClearances.where((x) => x.caseId == caseId).toList();
    return Scaffold(
      appBar: AppBar(title: Text(c.creditorName, style: const TextStyle(fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (cert != null) ...[
            GestureDetector(
              onTap: () => showCertificate(context, cert),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFF7E0), Colors.white]), borderRadius: BorderRadius.circular(16), border: Border.all(color: XgColors.gold, width: 1.5)),
                child: Row(children: [
                  const Icon(Icons.workspace_premium, color: XgColors.goldDark, size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('此案件已结清 · 银行已出具结清证明', style: TextStyle(fontWeight: FontWeight.w800, color: XgColors.navyDark)),
                    Text('${cert.certNo} · 点击查看', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
                  ])),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          XCard(
            margin: EdgeInsets.zero,
            child: Column(children: [
              KV('案件编号', c.caseNo),
              KV('债务类型', c.debtType.label),
              KV('待还余额', fmtMoney(c.outstanding), bold: true, vColor: XgColors.danger),
              KV('本金/利息/罚息', '${fmtMoney(c.principal)} / ${fmtMoney(c.interest)} / ${fmtMoney(c.penalty)}'),
              KV('逾期', '${c.overdueDays} 天 · ${c.bucket} 桶'),
              KV('导入来源', c.importSource),
              KV('Consent ID', c.consentId),
              KV('协商状态', c.negotiationLabel, vColor: XgColors.navy, bold: true),
              KV('案件状态', c.statusLabel, vColor: c.status == 3 ? XgColors.success : null, bold: c.status == 3),
              const Divider(height: 16),
              KV('现金直付累计', fmtMoney(c.cashPaid + (active?.paidAmount ?? 0)), vColor: XgColors.success),
              KV('积分清缴累计', '${c.pointsCleared.toStringAsFixed(1)} DP', vColor: XgColors.coral),
            ]),
          ),
          const SizedBox(height: 12),
          // 两条平债通道
          if (c.status != 3)
            XCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('平债通道', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _channel(Icons.payments_outlined, '现金直付', '还款计划 · 月供自动扣款', XgColors.info)),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtPointsPage())), child: _channel(Icons.token_outlined, '债务积分', '${s.myAvailablePoints.toStringAsFixed(0)} DP 可转交银行', XgColors.coral))),
                ]),
              ]),
            ),
          if (c.status != 3) const SizedBox(height: 12),
          if (clearances.isNotEmpty) ...[
            XCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('银行清缴记录', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                ...clearances.map((x) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                  Tag(ClearanceStatus.label(x.status), color: x.status == 50 ? XgColors.success : XgColors.warning),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${x.points.toStringAsFixed(1)} DP · 现金 ${fmtMoney(x.cashRemitted)} · 减免 ${fmtMoney(x.reductionAccepted)}', style: const TextStyle(fontSize: 12))),
                  Text(fmtDate(x.createdAt), style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                ]))),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          // 还款方案状态机
          XCard(
            margin: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('还款方案状态机 RepaymentPlan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 12),
              StateFlow(
                steps: const [0, 1, 2, 3, 4],
                current: active?.status ?? (candidates.isNotEmpty ? candidates.map((p) => p.status).reduce((a, b) => a > b ? a : b) : (plans.isEmpty ? -1 : 0)),
                label: (i) => RepaymentPlan.statusLabels[i],
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (active != null) _ActivePlan(active, c),
          if (active == null && candidates.isEmpty)
            XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.sunrise,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Text('🧭', style: TextStyle(fontSize: 22)), SizedBox(width: 8), Text('让债务规划师生成方案', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))]),
                const SizedBox(height: 6),
                const Text('AG-01 将基于负债画像、月收入与逾期分桶，生成稳健 / 进取 / 决断三套备选方案，并自动通过 LPR×4 利率合规校验。', style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5)),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: XgColors.violet),
                  onPressed: () async {
                    final r = await s.call('POST', '/v1/repayment-plans/ai/generate', apiId: 'API-R-005', kycRequired: 3, body: {'case_id': c.caseId});
                    if (context.mounted) showApiResult(context, r, successText: 'AI 已生成 3 套方案 · ${r.data?['apr_check']}');
                  },
                  child: const Text('AI 生成还款方案 · API-R-005'),
                ),
              ]),
            ),
          if (candidates.isNotEmpty) ...[
            const Padding(padding: EdgeInsets.fromLTRB(0, 6, 0, 10), child: Text('AI 备选方案 · 请选择一套确认', style: TextStyle(fontWeight: FontWeight.w600))),
            ...candidates.map((p) => _PlanCard(p, c)),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => openAgent(context, 'AG-05'), icon: const Text('🤝'), label: const Text('让谈判专家起草协商函')),
        ],
      ),
    );
  }

  Widget _channel(IconData i, String t, String d, Color c) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(i, color: c, size: 20),
      const SizedBox(height: 4),
      Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: c)),
      Text(d, style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
    ]),
  );
}

class _PlanCard extends StatelessWidget {
  final RepaymentPlan p;
  final DebtCase c;
  const _PlanCard(this.p, this.c);
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final pending = p.status == 2;
    return XCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700))),
          Tag(p.model, color: XgColors.violet),
          const SizedBox(width: 4),
          Tag(p.statusLabel, color: pending ? XgColors.warning : XgColors.info),
        ]),
        const SizedBox(height: 6),
        Text(p.summary, style: const TextStyle(fontSize: 12, color: XgColors.textSecondary, height: 1.4)),
        const SizedBox(height: 10),
        Row(children: [
          StatTile(label: '方案总额', value: fmtMoney(p.totalAmount)),
          const SizedBox(width: 6),
          StatTile(label: '减免', value: fmtMoney(p.reductionAmount), color: XgColors.success),
          const SizedBox(width: 6),
          StatTile(label: p.periods == 1 ? '一次性' : '${p.periods} 期月供', value: fmtMoney(p.monthlyAmount)),
        ]),
        const SizedBox(height: 10),
        if (pending)
          const Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('已 e签宝 签署 · 等待债权方 Webhook 确认…', style: TextStyle(fontSize: 12, color: XgColors.textSecondary))])
        else
          FilledButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('确认方案'),
                  content: Text('确认「${p.title}」后将生成电子还款协议（e签宝），并推送 REPAYMENT.PLAN.CONFIRMED 至 ${c.creditorName}。其余备选方案将自动终止。'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确认'))],
                ),
              );
              if (ok != true) return;
              final r = await s.call('POST', '/v1/repayment-plans/${p.planId}/confirm', apiId: 'API-R-007', kycRequired: 3, requestId: 'confirm-${p.planId}');
              if (!context.mounted) return;
              showApiResult(context, r, successText: '已确认 · ${r.data?['e_sign']} · 等待债权方确认');
              Future.delayed(const Duration(milliseconds: 1700), s.refresh);
            },
            child: const Text('用户确认 · API-R-007'),
          ),
      ]),
    );
  }
}

class _ActivePlan extends StatelessWidget {
  final RepaymentPlan p;
  final DebtCase c;
  const _ActivePlan(this.p, this.c);
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return XCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700))),
          Tag(p.statusLabel, color: p.status == 4 ? XgColors.success : XgColors.info),
        ]),
        const SizedBox(height: 6),
        Text(p.summary, style: const TextStyle(fontSize: 12, color: XgColors.textSecondary, height: 1.4)),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: p.progress, minHeight: 8, backgroundColor: XgColors.bg, color: XgColors.gold)),
        const SizedBox(height: 8),
        Row(children: [
          Text('已还 ${p.paidPeriods}/${p.periods} 期 · ${fmtMoney(p.paidAmount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('月供 ${fmtMoney(p.monthlyAmount)}', style: const TextStyle(fontSize: 12, color: XgColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        KV('用户确认', p.userConfirmedAt == null ? '-' : fmtDay(p.userConfirmedAt!)),
        KV('债权方确认', p.creditorConfirmedAt == null ? '-' : fmtDay(p.creditorConfirmedAt!)),
        KV('履约分', '${(88 + p.paidPeriods * 0.5).toStringAsFixed(1)} → 信用重塑'),
        const SizedBox(height: 10),
        if (p.status == 3)
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final okTok = await verifyPayPassword(context);
                  if (!okTok || !context.mounted) return;
                  final r = await s.call('POST', '/v1/repayment-plans/${p.planId}/execute', apiId: 'API-R-008', kycRequired: 3, requirePayToken: true, requestId: 'exec-${p.planId}-${p.paidPeriods + 1}');
                  if (context.mounted) showApiResult(context, r, successText: '第 ${r.data?['paid_periods']} 期还款成功 · 凭证 ${r.data?['receipt_id']}');
                },
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('手动还本期 · API-R-008'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerPage())), child: const Text('账本')),
          ]),
      ]),
    );
  }
}
