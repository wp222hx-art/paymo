import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../pages/debt_points_pages.dart';
import '../pages/shell_page.dart';
import '../widgets/common.dart';

/// 银行清收专员 · 清缴单受理队列
class BankQueuePage extends StatefulWidget {
  const BankQueuePage({super.key});
  @override
  State<BankQueuePage> createState() => _BankQueuePageState();
}

class _BankQueuePageState extends State<BankQueuePage> {
  int _filter = 0; // 0 待处理 1 已完成 2 已退回 3 全部

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final org = s.me.orgName ?? '';
    final all = s.db.clearances.where((c) => c.bankName == org).toList();
    final list = switch (_filter) {
      0 => all.where((c) => c.status < 50).toList(),
      1 => all.where((c) => c.status == 50).toList(),
      2 => all.where((c) => c.status == 90).toList(),
      _ => all,
    };
    final pending = all.where((c) => c.status == 10).length;
    final inProgress = all.where((c) => c.status > 10 && c.status < 50).length;
    final cashToday = all.where((c) => c.status >= 30 && c.status != 90).fold(0.0, (a, c) => a + c.cashRemitted);
    final written = all.where((c) => c.status == 50).fold(0.0, (a, c) => a + c.points);
    return Scaffold(
      appBar: XgAppBar(title: org, actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => s.call('GET', '/v1/bank/clearances', apiId: 'BANK-CL-LIST', permission: 'bank.clearance.view')),
      ]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.navyGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Icon(Icons.account_balance, color: XgColors.gold, size: 18), SizedBox(width: 6), Text('债权方工作台 · 开放平台接入', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                const SizedBox(height: 10),
                Row(children: [
                  _m('待受理', '$pending', pending > 0 ? XgColors.gold : Colors.white),
                  _m('处理中', '$inProgress', Colors.white),
                  _m('已确认收款', fmtMoney(cashToday), Colors.white),
                  _m('累计核销', '${written.toStringAsFixed(0)} DP', XgColors.gold),
                ]),
                const SizedBox(height: 10),
                const Text('AppKey + HMAC-SHA256 签名 · Webhook CLEARANCE.* / CERTIFICATE.ISSUED 回推平台 · 数据按机构租户隔离（ABAC）', style: TextStyle(color: Colors.white54, fontSize: 10)),
              ]),
            ),
          ),
          const SectionTitle('清缴单处理流程'),
          XCard(
            padding: const EdgeInsets.all(12),
            child: Column(children: const [
              _StepRow('10', '已提交', '用户将债务积分转交本行，平台已冻结现金背书'),
              _StepRow('20', '受理', '专员核验 Consent、积分背书比例、案件归属'),
              _StepRow('30', '确认收款', '核对平台存管账户汇入的现金背书（银联流水）'),
              _StepRow('40', '核销', '按积分面值核销债务；可选择是否接受协商减免部分'),
              _StepRow('50', '完成 → 结清证明', '案件余额归零后，专员签发《债务结清证明》'),
            ]),
          ),
          SectionTitle('受理队列（${list.length}）', action: ['待处理', '已完成', '已退回', '全部'][_filter], onAction: () => setState(() => _filter = (_filter + 1) % 4)),
          if (list.isEmpty) const EmptyHint('队列为空'),
          ...list.map((c) => _BankClearanceCard(c)),
        ],
      ),
    );
  }

  Widget _m(String l, String v, Color c) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w800)), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10))]));
}

class _StepRow extends StatelessWidget {
  final String code, name, desc;
  const _StepRow(this.code, this.name, this.desc);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 28, padding: const EdgeInsets.symmetric(vertical: 2), decoration: BoxDecoration(color: XgColors.navy, borderRadius: BorderRadius.circular(4)), alignment: Alignment.center, child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 11, color: XgColors.textSecondary))),
      ]),
    );
  }
}

class _BankClearanceCard extends StatelessWidget {
  final ClearanceOrder c;
  const _BankClearanceCard(this.c);
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final user = s.db.users[c.userId];
    final kase = s.db.debtCases.firstWhere((k) => k.caseId == c.caseId);
    final color = c.status == 50 ? XgColors.success : (c.status == 90 ? XgColors.danger : (c.status == 10 ? XgColors.gold : XgColors.info));
    final backing = c.points == 0 ? 0 : c.cashRemitted / c.points;
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Tag(ClearanceStatus.label(c.status), color: color == XgColors.gold ? XgColors.goldDark : color),
          const SizedBox(width: 6),
          Text(c.clearanceId, style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          const Spacer(),
          Text(fmtDate(c.createdAt), style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (user != null) Avatar(user, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${user?.nickname ?? c.userId} · ${KycLevel.name(user?.kycLevel ?? 0)} · 平台履约 ${user?.creditScore ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('案件 ${kase.caseNo} · 待还 ${fmtMoney(kase.outstanding)} · ${kase.bucket}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          StatTile(label: '申请核销', value: '${c.points.toStringAsFixed(1)} DP'),
          const SizedBox(width: 6),
          StatTile(label: '现金背书', value: fmtMoney(c.cashRemitted), color: XgColors.success),
          const SizedBox(width: 6),
          StatTile(label: '申请减免', value: fmtMoney(c.reductionAccepted), color: XgColors.coral),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: backing.toDouble(), minHeight: 6, backgroundColor: XgColors.coral.withValues(alpha: 0.3), color: XgColors.success))),
          const SizedBox(width: 8),
          Text('背书率 ${(backing * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        if (c.status < 50 && c.status != 90) ...[
          const SizedBox(height: 10),
          StateFlow(steps: ClearanceStatus.flow, current: c.status, label: ClearanceStatus.label),
        ],
        if (c.rejectReason != null) ...[
          const SizedBox(height: 8),
          Text('退回原因：${c.rejectReason}', style: const TextStyle(fontSize: 12, color: XgColors.danger)),
        ],
        const SizedBox(height: 12),
        _actions(context, s, kase),
        const Divider(height: 20),
        ...c.history.reversed.take(4).map((h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.operator.startsWith('BANK') ? '🏦' : (h.operator.startsWith('USER') ? '👤' : '⚙️'), style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 6),
                Expanded(child: Text('${ClearanceStatus.label(h.status)} · ${h.note}', style: const TextStyle(fontSize: 11))),
                Text(fmtDate(h.at), style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
              ]),
            )),
      ]),
    );
  }

  Widget _actions(BuildContext context, AppState s, DebtCase kase) {
    Future<void> act(String action, {Map<String, dynamic>? body, String? ok, String perm = 'bank.clearance.accept'}) async {
      final r = await s.call('POST', '/v1/bank/clearances/${c.clearanceId}/$action', apiId: 'BANK-CL-${action.toUpperCase()}', permission: perm, requestId: 'bank-${c.clearanceId}-$action', body: body);
      if (context.mounted) showApiResult(context, r, successText: ok ?? 'success');
    }

    switch (c.status) {
      case 10:
        return Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => act('accept', ok: '已受理 · 等待平台汇款到账'), icon: const Icon(Icons.how_to_reg, size: 18), label: const Text('受理'))),
          const SizedBox(width: 8),
          OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: XgColors.danger, side: const BorderSide(color: XgColors.danger)), onPressed: () => _rejectDialog(context, act), child: const Text('退回')),
        ]);
      case 20:
        return Row(children: [
          Expanded(child: FilledButton.icon(onPressed: () => act('confirm-remit', perm: 'bank.clearance.confirm_remit', ok: '已确认收到 ${fmtMoney(c.cashRemitted)} · 可核销'), icon: const Icon(Icons.price_check, size: 18), label: const Text('确认收款到账'))),
          const SizedBox(width: 8),
          OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: XgColors.danger, side: const BorderSide(color: XgColors.danger)), onPressed: () => _rejectDialog(context, act), child: const Text('退回')),
        ]);
      case 30:
        return Column(children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: XgColors.success),
            onPressed: () => act('write-off', perm: 'bank.clearance.write_off', body: {'accept_reduction': true}, ok: '已核销 ${c.points.toStringAsFixed(1)} DP（含减免 ${fmtMoney(c.reductionAccepted)}）'),
            icon: const Icon(Icons.task_alt, size: 18),
            label: Text('核销 ${c.points.toStringAsFixed(1)} DP（接受协商减免）'),
          ),
          if (c.reductionAccepted > 0) ...[
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () => act('write-off', perm: 'bank.clearance.write_off', body: {'accept_reduction': false}, ok: '仅核销现金部分 ${fmtMoney(c.cashRemitted)}'),
              child: Text('仅核销现金部分 ${fmtMoney(c.cashRemitted)}（不接受减免）', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ]);
      case 50:
        if (kase.outstanding <= 0.005 && kase.certificateId == null) {
          return FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: XgColors.goldDark),
            onPressed: () => act('issue-certificate', perm: 'bank.certificate.issue', ok: '《债务结清证明》已签发并推送用户'),
            icon: const Icon(Icons.workspace_premium, size: 18),
            label: const Text('签发《债务结清证明》'),
          );
        }
        if (kase.certificateId != null) {
          final cert = s.db.certificates.firstWhere((x) => x.certId == kase.certificateId);
          return OutlinedButton.icon(onPressed: () => showCertificate(context, cert), icon: const Icon(Icons.workspace_premium, size: 18, color: XgColors.goldDark), label: Text('查看结清证明 ${cert.certNo}', style: const TextStyle(fontSize: 12)));
        }
        return Row(children: [const Icon(Icons.check_circle, size: 16, color: XgColors.success), const SizedBox(width: 6), Text('已完成 · 案件剩余 ${fmtMoney(kase.outstanding)}', style: const TextStyle(fontSize: 12, color: XgColors.success))]);
      default:
        return const SizedBox.shrink();
    }
  }

  void _rejectDialog(BuildContext context, Future<void> Function(String, {Map<String, dynamic>? body, String? ok, String perm}) act) {
    final ctrl = TextEditingController(text: '积分背书凭证不全，请补充平台结算单');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退回清缴单'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(labelText: '退回原因（将推送给用户）')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: XgColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              act('reject', perm: 'bank.clearance.reject', body: {'reason': ctrl.text}, ok: '已退回 · 积分已返还用户');
            },
            child: const Text('确认退回'),
          ),
        ],
      ),
    );
  }
}

/// 本行案件视图
class BankCasesPage extends StatelessWidget {
  const BankCasesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final org = s.me.orgName ?? '';
    final cases = s.db.debtCases.where((c) => c.creditorName == org).toList();
    final total = cases.fold(0.0, (a, c) => a + c.outstanding);
    final cleared = cases.where((c) => c.status == 3).length;
    return Scaffold(
      appBar: const XgAppBar(title: '本行案件 · 租户视图'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              StatTile(label: '在管案件', value: '${cases.length}', icon: Icons.folder_outlined),
              const SizedBox(width: 8),
              StatTile(label: '待回收', value: fmtMoney(total), icon: Icons.account_balance_wallet_outlined, color: XgColors.danger),
              const SizedBox(width: 8),
              StatTile(label: '已结清', value: '$cleared', icon: Icons.verified_outlined, color: XgColors.success),
            ]),
          ),
          const SectionTitle('案件列表 · debt.case.view.tenant'),
          if (cases.isEmpty) const EmptyHint('本行暂无接入案件'),
          ...cases.map((c) {
            final u = s.db.users[c.userId];
            final plan = s.db.plans.where((p) => p.planId == c.planId).firstOrNull;
            final cert = c.certificateId == null ? null : s.db.certificates.where((x) => x.certId == c.certificateId).firstOrNull;
            return XCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              onTap: cert == null ? null : () => showCertificate(context, cert),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (u != null) Avatar(u, size: 32),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u?.nickname ?? c.userId, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${c.caseNo} · ${c.debtType.label}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
                  ])),
                  Tag(c.statusLabel, color: c.status == 3 ? XgColors.success : XgColors.info),
                  const SizedBox(width: 4),
                  Tag(c.bucket, color: c.overdueDays > 90 ? XgColors.danger : XgColors.warning),
                ]),
                const Divider(height: 18),
                KV('待还余额', fmtMoney(c.outstanding), bold: true, vColor: c.outstanding == 0 ? XgColors.success : XgColors.danger),
                KV('原始债务', fmtMoney(c.originalDebt)),
                KV('现金清偿', fmtMoney(c.cashPaid + (plan?.paidAmount ?? 0)), vColor: XgColors.success),
                KV('积分核销', '${c.pointsCleared.toStringAsFixed(1)} DP', vColor: XgColors.coral),
                KV('协商状态', c.negotiationLabel),
                if (plan != null) KV('还款方案', '${plan.title} · ${plan.paidPeriods}/${plan.periods} 期'),
                if (cert != null) KV('结清证明', '${cert.certNo} · 点击查看', vColor: XgColors.goldDark, bold: true),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
