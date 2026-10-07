import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/mock_db.dart';
import '../../state/app_state.dart';
import '../../core/module_info.dart';
import '../widgets/common.dart';
import '../widgets/module_widgets.dart';
import 'wallet_pages.dart';

Color sourceColor(DebtPointSource s) => switch (s) {
  DebtPointSource.task => XgColors.info,
  DebtPointSource.content => XgColors.violet,
  DebtPointSource.consumption => XgColors.coral,
  DebtPointSource.lightPoints => XgColors.goldDark,
};

IconData sourceIcon(DebtPointSource s) => switch (s) {
  DebtPointSource.task => Icons.work_outline,
  DebtPointSource.content => Icons.play_circle_outline,
  DebtPointSource.consumption => Icons.shopping_bag_outlined,
  DebtPointSource.lightPoints => Icons.bolt,
};

/// 债务积分中心：平台核心闭环的驾驶舱
class DebtPointsPage extends StatefulWidget {
  const DebtPointsPage({super.key});
  @override
  State<DebtPointsPage> createState() => _DebtPointsPageState();
}

class _DebtPointsPageState extends State<DebtPointsPage> {
  @override
  void initState() {
    super.initState();
    // 清缴单由银行异步推进，定时刷新视图
    _tick();
  }

  void _tick() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted && context.read<AppState>().myClearances.any((c) => c.status < ClearanceStatus.done)) {
        context.read<AppState>().refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final avail = s.myAvailablePoints;
    final cash = s.myCashBacked;
    final ratio = avail == 0 ? 0.0 : cash / avail;
    final batches = s.myDebtPoints;
    final clearances = s.myClearances;
    final certs = s.myCertificates;
    final openCases = s.myCases.where((c) => c.status != 3).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('债务积分 · 银行清缴'), actions: [
        const InfoButton(Modules.debtPoints),
        IconButton(icon: const Icon(Icons.storefront_outlined), tooltip: '消费平债商城', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OffsetShopPage()))),
      ]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── 积分池 Hero ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.navyGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.token_outlined, color: XgColors.gold, size: 18), SizedBox(width: 6), Text('可用债务积分 · 1 DP = ¥1 抵扣面值', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(avail.toStringAsFixed(1), style: const TextStyle(color: XgColors.gold, fontSize: 36, fontWeight: FontWeight.w800)),
                  const Padding(padding: EdgeInsets.only(bottom: 8, left: 6), child: Text('DP', style: TextStyle(color: XgColors.gold, fontSize: 16, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: XgColors.coral.withValues(alpha: 0.5), color: XgColors.success),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: XgColors.success, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('现金背书 ${fmtMoney(cash)}（${(ratio * 100).toStringAsFixed(0)}%）', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  const SizedBox(width: 12),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: XgColors.coral.withValues(alpha: 0.8), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('协商减免 ${fmtMoney(avail - cash)}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ]),
                const SizedBox(height: 10),
                const Text('平台将真实资金（现金背书）汇至银行，银行按积分面值核销债务；差额部分为银行基于平台数据接受的协商减免。', style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.4)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: XgColors.gold, foregroundColor: XgColors.navyDark),
                      onPressed: avail <= 0 || openCases.isEmpty ? null : () => _submitSheet(context, openCases),
                      icon: const Icon(Icons.account_balance, size: 18),
                      label: const Text('转交银行清缴'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OffsetShopPage())),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('消费平债'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),

          // ── 四大来源 ──
          const SectionTitle('积分来源 · 所有平台价值创造统一汇入'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: DebtPointSource.values.map((src) {
              final v = s.pointsBySource(src);
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: src == DebtPointSource.lightPoints ? 0 : 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: XgColors.divider)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(sourceIcon(src), size: 18, color: sourceColor(src)),
                    const SizedBox(height: 6),
                    Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: sourceColor(src))),
                    Text(src.label, style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                  ]),
                ),
              );
            }).toList()),
          ),

          // ── 闭环示意 ──
          const SectionTitle('核心闭环 · 价值 → 积分 → 银行 → 结清单'),
          XCard(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _flowRow('①', '任务 / 内容 / 消费 / 光芒值', '产生债务积分（含现金背书）', XgColors.info),
              _flowArrow(),
              _flowRow('②', '用户选择案件转交银行', 'API /v1/clearance/submit', XgColors.violet),
              _flowArrow(),
              _flowRow('③', '平台汇出现金背书', '银行受理 → 资金划付（复式记账）', XgColors.coral),
              _flowArrow(),
              _flowRow('④', '银行按积分核销债务', '余额归零 → 出具《债务结清证明》', XgColors.success),
            ]),
          ),

          // ── 结清证明 ──
          if (certs.isNotEmpty) ...[
            const SectionTitle('债务结清证明 · 银行出具'),
            ...certs.map((c) => _CertCard(c)),
          ],

          // ── 清缴单 ──
          if (clearances.isNotEmpty) ...[
            const SectionTitle('银行清缴单 · 状态机'),
            ...clearances.map((c) => _ClearanceCard(c)),
          ],

          // ── 积分批次 ──
          SectionTitle('积分批次明细（${batches.length}）'),
          if (batches.isEmpty) const EmptyHint('还没有债务积分 · 去完成任务、发布内容或消费吧'),
          ...batches.map((b) => Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: XgColors.divider)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: sourceColor(b.source).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(sourceIcon(b.source), size: 18, color: sourceColor(b.source))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${b.batchId} · 背书 ${(b.backingRatio * 100).toStringAsFixed(0)}% · ${fmtDate(b.createdAt)}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${b.remaining.toStringAsFixed(1)} DP', style: TextStyle(fontWeight: FontWeight.w700, color: b.remaining == 0 ? XgColors.textSecondary : XgColors.textPrimary, decoration: b.remaining == 0 ? TextDecoration.lineThrough : null)),
                    if (b.consumed > 0) Text('已清缴 ${b.consumed.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: XgColors.success)),
                  ]),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _flowRow(String n, String a, String b, Color c) => Row(children: [
    Container(width: 26, height: 26, decoration: BoxDecoration(color: c, shape: BoxShape.circle), alignment: Alignment.center, child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text(b, style: const TextStyle(fontSize: 11, color: XgColors.textSecondary))])),
  ]);
  Widget _flowArrow() => const Padding(padding: EdgeInsets.only(left: 9, top: 2, bottom: 2), child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.arrow_downward, size: 14, color: XgColors.divider)));

  void _submitSheet(BuildContext context, List<DebtCase> cases) {
    final s = context.read<AppState>();
    var selected = cases.first;
    final avail = s.myAvailablePoints;
    double pts = avail.clamp(0, cases.first.outstanding);
    showXSheet(
      context,
      title: '转交银行清缴 · /v1/clearance/submit',
      StatefulBuilder(builder: (ctx, setSt) {
        final cashRatio = avail == 0 ? 0 : s.myCashBacked / avail;
        final cash = pts * cashRatio;
        return ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          const Text('选择债务案件', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ...cases.map((c) => GestureDetector(
                onTap: () => setSt(() {
                  selected = c;
                  pts = avail.clamp(0, c.outstanding);
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: selected == c ? XgColors.navy.withValues(alpha: 0.06) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected == c ? XgColors.navy : XgColors.divider, width: selected == c ? 1.5 : 1)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.creditorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text('待还 ${fmtMoney(c.outstanding)} · ${c.bucket}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary))])),
                    Icon(selected == c ? Icons.radio_button_checked : Icons.radio_button_off, color: selected == c ? XgColors.navy : XgColors.divider, size: 20),
                  ]),
                ),
              )),
          const SizedBox(height: 8),
          Text('转交积分：${pts.toStringAsFixed(1)} DP', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Slider(value: pts, min: 0, max: avail.clamp(0.01, double.infinity) < selected.outstanding ? avail : selected.outstanding, activeColor: XgColors.gold, onChanged: (v) => setSt(() => pts = v)),
          XCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              KV('核销面值', '${pts.toStringAsFixed(1)} DP = ${fmtMoney(pts)}', bold: true),
              KV('平台汇出现金', fmtMoney(cash), vColor: XgColors.success),
              KV('申请协商减免', fmtMoney(pts - cash), vColor: XgColors.coral),
              KV('清缴后待还', fmtMoney(selected.outstanding - pts)),
              if (selected.outstanding - pts <= 0.005) const KV('结果', '余额归零 → 银行将出具《债务结清证明》', vColor: XgColors.success, bold: true),
            ]),
          ),
          const SizedBox(height: 8),
          Text('合规校验：Consent 有效 · KYC ≥ L3 · 幂等级别 L4（Saga 状态机）· ${s.db.users.values.any((u) => u.role.isBank && u.orgName == selected.creditorName) ? '该行已接入开放平台，由清收专员人工受理、确认收款、核销并签发结清证明' : '该债权方走系统对接，Webhook 自动推进'}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: pts <= 0
                ? null
                : () async {
                    final ok = await verifyPayPassword(ctx);
                    if (!ok || !ctx.mounted) return;
                    final r = await s.call('POST', '/v1/clearance/submit', apiId: 'API-R-016', kycRequired: 3, requirePayToken: true, requestId: 'cl-${selected.caseId}-${pts.toStringAsFixed(0)}', body: {'case_id': selected.caseId, 'points': pts});
                    if (!ctx.mounted) return;
                    showApiResult(ctx, r, successText: '清缴单 ${r.data?['clearance_id']} 已提交 · 银行处理中');
                    if (r.ok) Navigator.pop(ctx);
                  },
            child: const Text('提交银行清缴（需支付密码）'),
          ),
          const SizedBox(height: 20),
        ]);
      }),
    );
  }
}

class _ClearanceCard extends StatelessWidget {
  final ClearanceOrder c;
  const _ClearanceCard(this.c);
  @override
  Widget build(BuildContext context) {
    final done = c.status == ClearanceStatus.done;
    final rejected = c.status == ClearanceStatus.rejected;
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.bankName, style: const TextStyle(fontWeight: FontWeight.w700))),
          Tag(ClearanceStatus.label(c.status), color: done ? XgColors.success : (rejected ? XgColors.danger : XgColors.warning)),
        ]),
        Text('${c.clearanceId} · ${fmtDate(c.createdAt)}${c.bankOperator != null ? ' · 受理专员 ${c.bankOperator}' : ''}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
        if (c.status == 10) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: XgColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [Icon(Icons.hourglass_top, size: 14, color: XgColors.goldDark), SizedBox(width: 6), Expanded(child: Text('已推送至银行清收专员，等待人工受理（SLA 1 个工作日）', style: TextStyle(fontSize: 11, color: XgColors.goldDark)))]),
          ),
        ],
        if (rejected) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: XgColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [const Icon(Icons.undo, size: 14, color: XgColors.danger), const SizedBox(width: 6), Expanded(child: Text('银行退回：${c.rejectReason ?? ''} · 积分已返还至积分池，可补充资料后重新提交', style: const TextStyle(fontSize: 11, color: XgColors.danger)))]),
          ),
        ],
        const SizedBox(height: 14),
        if (!rejected) StateFlow(steps: ClearanceStatus.flow, current: c.status, label: ClearanceStatus.label),
        const SizedBox(height: 12),
        Row(children: [
          StatTile(label: '核销积分', value: '${c.points.toStringAsFixed(1)} DP'),
          const SizedBox(width: 6),
          StatTile(label: '汇出现金', value: fmtMoney(c.cashRemitted), color: XgColors.success),
          const SizedBox(width: 6),
          StatTile(label: '协商减免', value: fmtMoney(c.reductionAccepted), color: XgColors.coral),
        ]),
        const SizedBox(height: 10),
        ...c.history.reversed.map((h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: h.status == 50 ? XgColors.success : XgColors.navy, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text('${ClearanceStatus.label(h.status)} · ${h.note}', style: const TextStyle(fontSize: 11))),
                Text(fmtDate(h.at), style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
              ]),
            )),
      ]),
    );
  }
}

class _CertCard extends StatelessWidget {
  final ClearanceCertificate c;
  const _CertCard(this.c);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showCertificate(context, c),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFF7E0), Color(0xFFFFFFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: XgColors.gold, width: 1.5),
          boxShadow: [BoxShadow(color: XgColors.gold.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(color: XgColors.gold, shape: BoxShape.circle), child: const Icon(Icons.workspace_premium, color: XgColors.navyDark, size: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('债务结清证明 · ${c.bankName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: XgColors.navyDark)),
            Text('编号 ${c.certNo} · ${fmtDay(c.issuedAt)}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
            const SizedBox(height: 4),
            Text('结清 ${fmtMoney(c.totalCleared)} · 点击查看', style: const TextStyle(fontSize: 11, color: XgColors.goldDark, fontWeight: FontWeight.w600)),
          ])),
          const Icon(Icons.chevron_right, color: XgColors.goldDark),
        ]),
      ),
    );
  }
}

void showCertificate(BuildContext context, ClearanceCertificate c) {
  final s = context.read<AppState>();
  final user = s.db.users[c.userId];
  showXSheet(
    context,
    ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: XgColors.gold, width: 2),
        ),
        child: Column(children: [
          const Icon(Icons.account_balance, size: 36, color: XgColors.navy),
          const SizedBox(height: 6),
          Text(c.bankName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: XgColors.navyDark)),
          const SizedBox(height: 14),
          const Text('债务结清证明', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 6, color: XgColors.navyDark)),
          const Text('Certificate of Debt Settlement', style: TextStyle(fontSize: 10, color: XgColors.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 18),
          Text(
            '兹证明 ${user?.nickname ?? c.userId}（平台 UUID ${user?.uuid.substring(0, 8) ?? ''}…）名下本行案件 ${c.caseNo} 项下全部债务，已通过「新光云 · 负债人赋能平台」债务积分清缴机制结清，本行不再对该笔债务主张任何权利。',
            style: const TextStyle(fontSize: 13, height: 1.8),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 16),
          const Divider(),
          KV('证明编号', c.certNo, bold: true),
          KV('原始债务', fmtMoney(c.originalDebt)),
          KV('结清总额', fmtMoney(c.totalCleared), bold: true, vColor: XgColors.success),
          KV('其中：现金清偿', fmtMoney(c.cashPaid)),
          KV('其中：积分减免', fmtMoney(c.pointsReduction), vColor: XgColors.coral),
          KV('出具日期', fmtDay(c.issuedAt)),
          KV('签发人', c.issuedBy),
          KV('电子签章', c.signature, vColor: XgColors.textSecondary),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: XgColors.danger, width: 2.5)),
              alignment: Alignment.center,
              child: Text('${c.bankName.substring(0, 2)}\n结清专用章', textAlign: TextAlign.center, style: const TextStyle(color: XgColors.danger, fontSize: 11, fontWeight: FontWeight.w700, height: 1.4)),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      const Text('该证明由银行通过开放平台接口（Webhook CERTIFICATE.ISSUED）推送，SM2 电子签章可在央行征信中心与本平台双向核验；征信逾期记录将于结清后 5 年自动消除。', style: TextStyle(fontSize: 11, color: XgColors.textSecondary, height: 1.5)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => showApiResult(context, ApiResponse(code: 0, message: 'success', traceId: 'tr-cert-pdf', serverTime: 0), successText: 'PDF 已生成（e签宝存证）· 发送至邮箱'), icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: const Text('下载 PDF'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.icon(onPressed: () => showApiResult(context, ApiResponse(code: 0, message: 'success', traceId: 'tr-cert-share', serverTime: 0), successText: '已生成「我上岸了」分享海报 · 带归因短链'), icon: const Icon(Icons.celebration_outlined, size: 18), label: const Text('分享上岸'))),
      ]),
      const SizedBox(height: 20),
    ]),
  );
}

// ───────────────────────── 本地生活 · 消费平债 ─────────────────────────

class OffsetShopPage extends StatefulWidget {
  const OffsetShopPage({super.key});
  @override
  State<OffsetShopPage> createState() => _OffsetShopPageState();
}

class _OffsetShopPageState extends State<OffsetShopPage> {
  String? _cat;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final orders = s.myShopOrders;
    final totalOffset = orders.fold(0.0, (a, o) => a + o.offsetAmount);
    final monthly = s.myMonthlyRepayment;
    final all = s.products;
    final list = _cat == null ? all : all.where((p) => p.category == _cat).toList();
    // 热门：按抵债 DP 最高
    final hot = [...all]..sort((a, b) => (b.platformMargin * s.quoteFor(b).finalMultiplier).compareTo(a.platformMargin * s.quoteFor(a).finalMultiplier));
    final days = monthly <= 0 ? 0.0 : totalOffset / (monthly / 30);
    return Scaffold(
      appBar: AppBar(title: const Text('本地生活 · 消费平债'), actions: const [InfoButton(Modules.shop)]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const ModuleBanner(Modules.shop),
          // Hero
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.sunrise,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.wb_sunny_outlined, color: Colors.white), SizedBox(width: 8), Text('边消费，边平债', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))]),
                const SizedBox(height: 6),
                Text('该花的钱照花。平台分到的利润按倍率变成你的债务积分。你的信用重塑分 ${s.me.creditScore}，当前享受 ${s.quoteFor(all.first).creditBonus > 0 ? '+${s.quoteFor(all.first).creditBonus.toStringAsFixed(1)} 信用加成' : '基础倍率'}。', style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${totalOffset.toStringAsFixed(1)} DP', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      const Text('累计消费平债', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ])),
                    Container(width: 1, height: 36, color: Colors.white30),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(days >= 0.1 ? '≈ ${days.toStringAsFixed(1)} 天' : '—', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const Text('相当于少还的天数', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${orders.length}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const Text('订单', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),

          // 分类宫格
          const SectionTitle('服务分类 · 8 大本地生活场景'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: MockDb.shopCategories.map((c) {
                final sel = _cat == c.$1;
                final n = all.where((p) => p.category == c.$1).length;
                return GestureDetector(
                  onTap: () => setState(() => _cat = sel ? null : c.$1),
                  child: Container(
                    decoration: BoxDecoration(color: sel ? XgColors.navy : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? XgColors.navy : XgColors.divider)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(c.$2, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(c.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? Colors.white : XgColors.textPrimary)),
                      Text('$n 项', style: TextStyle(fontSize: 9, color: sel ? Colors.white70 : XgColors.textSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),

          // 高抵债精选
          if (_cat == null) ...[
            const SectionTitle('高抵债精选 · 同样花钱，抵得更多'),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final p = hot[i];
                  final q = s.quoteFor(p);
                  final dp = p.platformMargin * q.finalMultiplier;
                  return GestureDetector(
                    onTap: () => _buy(context, s, p, q),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: XgColors.divider)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Text(p.emoji, style: const TextStyle(fontSize: 26)), const Spacer(), DebtImpactBadge(dp: dp, monthlyRepayment: monthly, compact: true)]),
                        const SizedBox(height: 8),
                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
                        const Spacer(),
                        Row(children: [
                          Text(fmtMoney(p.price), style: const TextStyle(fontWeight: FontWeight.w800, color: XgColors.navy)),
                          const Spacer(),
                          Text('抵 ${(dp / p.price * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: XgColors.coral, fontWeight: FontWeight.w700)),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],

          SectionTitle(_cat == null ? '全部服务（${list.length}）' : '$_cat（${list.length}）', action: _cat == null ? null : '清除筛选', onAction: () => setState(() => _cat = null)),
          ...list.map((p) => _ProductCard(p, monthly: monthly, onBuy: (q) => _buy(context, s, p, q))),

          if (orders.isNotEmpty) ...[
            const SectionTitle('我的消费订单'),
            ...orders.map((o) => Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: XgColors.divider)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${o.orderId} · ${fmtDate(o.createdAt)} · ${o.status == 'fulfilled' ? '已履约' : '已支付'}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmtMoney(o.price), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('+${o.offsetAmount.toStringAsFixed(1)} DP', style: const TextStyle(fontSize: 11, color: XgColors.coral, fontWeight: FontWeight.w700)),
                    ]),
                  ]),
                )),
          ],
        ],
      ),
    );
  }

  void _buy(BuildContext context, AppState s, Product p, OffsetQuote q) {
    final offset = p.platformMargin * q.finalMultiplier;
    final monthly = s.myMonthlyRepayment;
    String channel = 'wallet';
    showXSheet(
      context,
      title: '确认下单',
      StatefulBuilder(builder: (ctx, setSt) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: XgColors.bg, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(p.emoji, style: const TextStyle(fontSize: 30))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('${p.merchant} · ${p.desc}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 14),
        Center(child: DebtImpactBadge(dp: offset, monthlyRepayment: monthly)),
        const SizedBox(height: 14),
        XCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            KV('商品价格', fmtMoney(p.price), bold: true),
            KV('商家实收', fmtMoney(p.price - p.platformMargin)),
            KV('平台利润（让利）', fmtMoney(p.platformMargin), vColor: XgColors.success),
            KV('你的倍率', '× ${q.finalMultiplier.toStringAsFixed(1)}  ·  ${q.explain}'),
            KV('命中规则', q.appliedRules.join(' · '), vColor: XgColors.textSecondary),
            KV('获得债务积分', '${offset.toStringAsFixed(1)} DP', bold: true, vColor: XgColors.coral),
            KV('现金背书', '${fmtMoney(p.platformMargin)}（${(p.platformMargin / offset * 100).toStringAsFixed(0)}%）'),
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          for (final c in const [('wallet', '钱包余额'), ('wechat', '微信支付'), ('alipay', '支付宝')])
            ChoiceChip(label: Text(c.$2), selected: channel == c.$1, onSelected: (_) => setSt(() => channel = c.$1)),
        ]),
        const SizedBox(height: 8),
        const Text('复式分录：用户钱包/支付通道 D · 商家应付 C · 债务积分现金备付金 C。积分自动计入，可随时转交银行清缴。', style: TextStyle(fontSize: 10, color: XgColors.textSecondary)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () async {
            final r = await s.call('POST', '/v1/shop/orders', apiId: 'API-S-006', kycRequired: 1, requestId: 'so-${p.skuId}-${DateTime.now().millisecondsSinceEpoch}', body: {'sku_id': p.skuId, 'channel': channel});
            if (!ctx.mounted) return;
            if (!r.ok) {
              showApiResult(ctx, r);
              return;
            }
            Navigator.pop(ctx);
            if (context.mounted) _celebrate(context, s, p, (r.data['debt_points_issued'] as num).toDouble());
          },
          child: Text('支付 ${fmtMoney(p.price)} · 抵债 ${offset.toStringAsFixed(1)} DP'),
        ),
        const SizedBox(height: 20),
      ])),
    );
  }

  /// 下单成功 · 正向反馈
  void _celebrate(BuildContext context, AppState s, Product p, double dp) {
    final monthly = s.myMonthlyRepayment;
    final days = monthly <= 0 ? 0.0 : dp / (monthly / 30);
    final avail = s.myAvailablePoints;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: XgColors.sunrise, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: XgColors.violet.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🌅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text('这笔消费，也在还债', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${p.emoji} ${p.name}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 18),
            Text('+${dp.toStringAsFixed(1)} DP', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 4),
            Text(days >= 0.1 ? '相当于你的债务少还了 ${days.toStringAsFixed(1)} 天' : '已计入债务积分池', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.token_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('积分池现有 ${avail.toStringAsFixed(1)} DP · 可转交银行', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), onPressed: () => Navigator.pop(ctx), child: const Text('继续逛'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: XgColors.violet), onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtPointsPage()));
              }, child: const Text('去清缴'))),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product p;
  final double monthly;
  final void Function(OffsetQuote) onBuy;
  const _ProductCard(this.p, {required this.monthly, required this.onBuy});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = s.quoteFor(p);
    final offset = p.platformMargin * q.finalMultiplier;
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      onTap: () => onBuy(q),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: XgColors.bg, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(p.emoji, style: const TextStyle(fontSize: 28))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text('${p.merchant} · ${p.desc}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              Text(fmtMoney(p.price), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: XgColors.navy)),
              const SizedBox(width: 8),
              Tag(p.category, color: XgColors.info),
            ]),
          ])),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: () => onBuy(q),
            child: const Text('购买', style: TextStyle(fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          DebtImpactBadge(dp: offset, monthlyRepayment: monthly),
          const Spacer(),
          Text('利润 ¥${p.platformMargin} × ${q.finalMultiplier.toStringAsFixed(1)}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
        ]),
      ]),
    );
  }
}
