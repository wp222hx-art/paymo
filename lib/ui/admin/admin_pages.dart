import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../pages/community_page.dart';
import '../pages/shell_page.dart';
import '../pages/task_pages.dart';
import '../widgets/common.dart';

Color riskColor(int level) => [XgColors.textSecondary, XgColors.info, XgColors.warning, XgColors.danger, const Color(0xFF7F1D1D)][level];

// ───────────────────────── M02 风控台 ─────────────────────────

class RiskDashboardPage extends StatefulWidget {
  const RiskDashboardPage({super.key});
  @override
  State<RiskDashboardPage> createState() => _RiskDashboardPageState();
}

class _RiskDashboardPageState extends State<RiskDashboardPage> {
  String _filter = 'open';
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final all = s.riskCases;
    final list = _filter == 'all' ? all : all.where((c) => _filter == 'open' ? c.status != 'resolved' : c.status == 'resolved').toList();
    return Scaffold(
      appBar: const XgAppBar(title: '风控管理 · M02'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              StatTile(label: '待处置', value: '${all.where((c) => c.status != 'resolved').length}', icon: Icons.warning_amber_outlined, color: XgColors.danger),
              const SizedBox(width: 8),
              StatTile(label: '极高 L4', value: '${all.where((c) => c.level == 4 && c.status != 'resolved').length}', icon: Icons.local_fire_department_outlined, color: const Color(0xFF7F1D1D)),
              const SizedBox(width: 8),
              StatTile(label: '24h 命中', value: fmtInt(s.riskRules.fold(0, (a, r) => a + r.hitCount24h)), icon: Icons.rule),
              const SizedBox(width: 8),
              StatTile(label: '冻结用户', value: '${s.allUsers.where((u) => u.status == UserStatus.frozen).length}', icon: Icons.ac_unit, color: XgColors.info),
            ]),
          ),
          const SectionTitle('风险等级与处置策略'),
          XCard(
            padding: const EdgeInsets.all(12),
            child: Column(children: const [
              _LevelRow(1, '低', '60~74', '日志 + 用户提醒', '抽检'),
              _LevelRow(2, '中', '75~89', '二次验证（图形/短信/活体）', '24h 复核'),
              _LevelRow(3, '高', '90~99', '暂停业务 + 冻结金额', '4h 复核'),
              _LevelRow(4, '极高', '100 / 黑名单', '封禁 + 资金冻结 + 上报', '1h 应急'),
            ]),
          ),
          SectionTitle('案件管理 RC-208', action: {'open': '待处置', 'resolved': '已归档', 'all': '全部'}[_filter], onAction: () => setState(() => _filter = _filter == 'open' ? 'resolved' : (_filter == 'resolved' ? 'all' : 'open'))),
          if (list.isEmpty) const EmptyHint('没有案件'),
          ...list.map((c) => _RiskCaseCard(c)),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final int l;
  final String name, score, action, human;
  const _LevelRow(this.l, this.name, this.score, this.action, this.human);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(width: 36, padding: const EdgeInsets.symmetric(vertical: 2), decoration: BoxDecoration(color: riskColor(l), borderRadius: BorderRadius.circular(4)), alignment: Alignment.center, child: Text('L$l $name', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        SizedBox(width: 62, child: Text(score, style: const TextStyle(fontSize: 11))),
        Expanded(child: Text(action, style: const TextStyle(fontSize: 11))),
        Text(human, style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
      ]),
    );
  }
}

class _RiskCaseCard extends StatelessWidget {
  final RiskCase c;
  const _RiskCaseCard(this.c);
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final target = s.db.users[c.userId];
    final resolved = c.status == 'resolved';
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: riskColor(c.level), borderRadius: BorderRadius.circular(6)), child: Text('${RiskCase.levelLabel(c.level)} · ${c.score}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          Tag(c.scene, color: XgColors.info),
          const Spacer(),
          Text(c.caseId, style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        Text(c.ruleName, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('${c.ruleCode} · 建议处置：${c.suggestedAction}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.person_outline, size: 14, color: XgColors.textSecondary),
          const SizedBox(width: 4),
          Text('${c.userName} (${c.userId})${target != null ? ' · ${target.status.label} · 风险${['低', '中', '高', '极高'][target.riskLevel]}' : ''}', style: const TextStyle(fontSize: 11)),
          const Spacer(),
          Text(fmtDate(c.createdAt), style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
        ]),
        const SizedBox(height: 10),
        if (resolved)
          Row(children: [const Icon(Icons.check_circle, size: 16, color: XgColors.success), const SizedBox(width: 6), Text('已处置：${c.disposition} · 审计留痕 WORM', style: const TextStyle(fontSize: 12, color: XgColors.success))])
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            _act(context, 'log', '仅记录', XgColors.textSecondary),
            _act(context, 'challenge', '二次验证', XgColors.info),
            _act(context, 'freeze', '冻结账户', XgColors.warning),
            _act(context, 'ban', '封禁+上报', XgColors.danger),
            if (target?.status == UserStatus.frozen) _act(context, 'unfreeze', '解冻', XgColors.success),
            _act(context, 'downgrade', '误报·降级', XgColors.success),
          ]),
      ]),
    );
  }

  Widget _act(BuildContext context, String a, String label, Color color) {
    final s = context.read<AppState>();
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withValues(alpha: 0.6)), minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
      onPressed: () async {
        final r = await s.call('POST', '/v1/admin/risk/cases/${c.caseId}/dispose', apiId: 'ADM-RC-208', permission: 'risk.case.dispose', body: {'action': a});
        if (context.mounted) showApiResult(context, r, successText: '处置完成：$label · 审计 ${r.data?['audit_log_id']}');
      },
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class RiskRulesPage extends StatelessWidget {
  const RiskRulesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: const XgAppBar(title: '规则引擎 · RC-207'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Drools DSL 可视化配置 · 灰度发布 · AB 效果对比 · 发布需 risk.rule.publish 审批流', style: TextStyle(fontSize: 12, color: XgColors.textSecondary)),
          const SizedBox(height: 12),
          ...s.riskRules.map((r) => XCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(r.ruleCode, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 6),
                    Tag(r.scene, color: XgColors.info),
                    const Spacer(),
                    Tag(['草稿', '灰度', '生产', '关闭'][r.status], color: [XgColors.textSecondary, XgColors.warning, XgColors.success, XgColors.danger][r.status]),
                  ]),
                  const SizedBox(height: 4),
                  Text(r.ruleName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: XgColors.navyDark, borderRadius: BorderRadius.circular(8)),
                    child: Text(r.expression, style: const TextStyle(color: XgColors.gold, fontFamily: 'monospace', fontSize: 11)),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text('score ${r.riskScore}', style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 10),
                    Text('action ${r.action}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: XgColors.navy)),
                    const SizedBox(width: 10),
                    Text('24h 命中 ${r.hitCount24h}', style: const TextStyle(fontSize: 11)),
                    const Spacer(),
                    Text('误报 ${(r.fpRate * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: r.fpRate > 0.15 ? XgColors.danger : XgColors.textSecondary, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final st in const [(1, '灰度'), (2, '生产'), (3, '关闭')])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10)),
                          onPressed: r.status == st.$1
                              ? null
                              : () async {
                                  final rr = await s.call('PUT', '/v1/admin/risk/rules/${r.ruleCode}', apiId: 'ADM-RC-207', permission: 'risk.rule.create', body: {'status': st.$1});
                                  if (context.mounted) showApiResult(context, rr, successText: '${r.ruleCode} → ${st.$2}');
                                },
                          child: Text(st.$2, style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                  ]),
                ]),
              )),
        ],
      ),
    );
  }
}

// ───────────────────────── M01 运营看板 ─────────────────────────

class OpsDashboardPage extends StatelessWidget {
  const OpsDashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final db = s.db;
    final totalRepaid = db.users.values.fold<double>(0, (a, u) => a + u.carbonDebtSaved);
    final settled = db.orders.where((o) => o.status == 80).length;
    final disputeRate = db.orders.isEmpty ? 0 : db.orders.where((o) => o.status == 55).length / db.orders.length * 100;
    final violation = db.contents.isEmpty ? 0 : db.contents.where((c) => c.moderationStatus == 3).length / db.contents.length * 100;
    return Scaffold(
      appBar: XgAppBar(title: '运营看板 · OP-106', actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => s.call('GET', '/v1/admin/dashboard', apiId: 'ADM-OP-106', permission: 'ops.dashboard.read')),
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
                const Row(children: [Icon(Icons.star, color: XgColors.gold, size: 18), SizedBox(width: 6), Text('北极星指标 · 实时', style: TextStyle(color: Colors.white70, fontSize: 12))]),
                const SizedBox(height: 6),
                Text(fmtMoney(totalRepaid), style: const TextStyle(color: XgColors.gold, fontSize: 32, fontWeight: FontWeight.w800)),
                const Text('月度赎回进度总额（累计化解债务）', style: TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(height: 10),
                Row(children: [
                  _ns('赎回用户', '${db.debtProfiles.length}'),
                  _ns('债务积分发行', '${db.debtPoints.fold(0.0, (a, b) => a + b.faceValue).toStringAsFixed(0)} DP'),
                  _ns('银行核销', fmtMoney(db.clearances.where((c) => c.status >= 40).fold(0.0, (a, c) => a + c.points))),
                  _ns('结清证明', '${db.certificates.length} 张'),
                ]),
              ]),
            ),
          ),
          const SectionTitle('用户 / 内容 / 任务'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              Row(children: [
                const StatTile(label: 'DAU', value: '18,420', icon: Icons.people_outline),
                const SizedBox(width: 8),
                const StatTile(label: 'D7 留存', value: '46.2%', icon: Icons.replay, color: XgColors.success),
                const SizedBox(width: 8),
                StatTile(label: '发布量', value: '${db.contents.length}', icon: Icons.article_outlined),
                const SizedBox(width: 8),
                StatTile(label: '违规率', value: '${violation.toStringAsFixed(1)}%', icon: Icons.block, color: XgColors.danger),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                StatTile(label: '任务发布', value: '${db.tasks.length}', icon: Icons.campaign_outlined),
                const SizedBox(width: 8),
                StatTile(label: '已结算单', value: '$settled', icon: Icons.done_all, color: XgColors.success),
                const SizedBox(width: 8),
                StatTile(label: '争议率', value: '${disputeRate.toStringAsFixed(1)}%', icon: Icons.gavel_outlined, color: XgColors.warning),
                const SizedBox(width: 8),
                StatTile(label: '待审核', value: '${db.tasks.where((t) => t.status == 1).length}', icon: Icons.pending_outlined, color: XgColors.info),
              ]),
            ]),
          ),
          const SectionTitle('AI 指标 · 5 分钟刷新'),
          XCard(
            child: Column(children: [
              const KV('Agent 调用次数', '96,420 / 日 · ↑ 12.3%'),
              const KV('Token 消耗', '1.84 亿 · 成本 ¥3,210'),
              const KV('首字延迟 P99', '1.21 s（SLO ≤ 1.5 s ✓）', vColor: XgColors.success),
              const KV('满意度分', '+0.72（点赞率 − 点踩率）'),
              KV('API 日志条数', '${db.apiLogs.length}'),
            ]),
          ),
          const SectionTitle('债务积分 · 核心闭环指标'),
          XCard(
            child: Column(children: [
              KV('消费平债订单', '${db.shopOrders.length} 单 · 平台让利 ${fmtMoney(db.shopOrders.fold(0.0, (a, o) => a + o.platformMargin))}'),
              KV('消费平债积分', '${db.debtPoints.where((b) => b.source == DebtPointSource.consumption).fold(0.0, (a, b) => a + b.faceValue).toStringAsFixed(0)} DP'),
              KV('现金背书率', '${(db.debtPoints.fold(0.0, (a, b) => a + b.cashBacked) / db.debtPoints.fold(0.01, (a, b) => a + b.faceValue) * 100).toStringAsFixed(1)}%'),
              KV('清缴单', '${db.clearances.length} 单 · 处理中 ${db.clearances.where((c) => c.status < 50).length}', vColor: XgColors.info),
              KV('银行接受减免', fmtMoney(db.clearances.where((c) => c.status >= 40).fold(0.0, (a, c) => a + c.reductionAccepted)), vColor: XgColors.coral),
            ]),
          ),
          const SectionTitle('资金 / 合规 · 实时'),
          XCard(
            child: Column(children: [
              KV('复式账本分录', '${db.ledger.length} 条 · 借贷平衡 ✓', vColor: XgColors.success),
              KV('钱包总余额', fmtMoney(db.users.values.fold(0.0, (a, u) => a + u.walletBalance))),
              KV('保证金冻结', fmtMoney(db.users.values.fold(0.0, (a, u) => a + u.walletFrozen))),
              KV('风控待处置', '${db.riskCases.where((c) => c.status != 'resolved').length} 件', vColor: XgColors.danger),
              const KV('AML 报送', 'T+3 · 明日 09:00 截止 · 已生成'),
            ]),
          ),
          const SectionTitle('任务审核队列 · OP-103'),
          if (db.tasks.where((t) => t.status == 1).isEmpty) const EmptyHint('没有待审核任务'),
          ...db.tasks.where((t) => t.status == 1).map((t) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(children: [
                  TaskCard(task: t, compact: true),
                  Row(children: [
                    Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 36), backgroundColor: XgColors.success), onPressed: () async {
                      final r = await s.call('POST', '/v1/admin/tasks/audit/${t.taskId}', apiId: 'ADM-OP-103', permission: 'task.audit', body: {'approve': true});
                      if (context.mounted) showApiResult(context, r, successText: '任务审核通过 → 招募中');
                    }, child: const Text('通过'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), foregroundColor: XgColors.danger), onPressed: () async {
                      final r = await s.call('POST', '/v1/admin/tasks/audit/${t.taskId}', apiId: 'ADM-OP-103', permission: 'task.audit', body: {'approve': false});
                      if (context.mounted) showApiResult(context, r, successText: '任务已拒绝 → 已取消');
                    }, child: const Text('拒绝'))),
                  ]),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _ns(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10))]));
}

// ───────────────────────── 内容审核 ─────────────────────────

class ModerationPage extends StatelessWidget {
  const ModerationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final queue = s.moderationQueue;
    final rejected = s.db.contents.where((c) => c.moderationStatus == 3).toList();
    return Scaffold(
      appBar: const XgAppBar(title: '内容审核 · C-403 三审制'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              StatTile(label: '人工复审队列', value: '${queue.length}', icon: Icons.fact_check_outlined, color: XgColors.warning),
              const SizedBox(width: 8),
              StatTile(label: 'AI 直通', value: '${s.db.contents.where((c) => c.moderationStatus == 1).length}', icon: Icons.bolt, color: XgColors.success),
              const SizedBox(width: 8),
              StatTile(label: '已拒绝', value: '${rejected.length}', icon: Icons.block, color: XgColors.danger),
            ]),
          ),
          const SectionTitle('待人工复审（SLA ≤ 30 min）'),
          if (queue.isEmpty) const EmptyHint('队列为空 · 全部在 SLA 内'),
          ...queue.map((c) => Column(children: [
                ContentCard(c, showModeration: true),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: XgColors.bg, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Icon(Icons.smart_toy_outlined, size: 16, color: (c.aiScore ?? 0) >= 60 ? XgColors.success : XgColors.danger),
                        const SizedBox(width: 6),
                        Expanded(child: Text('AI 初审 ${c.aiScore?.toStringAsFixed(0) ?? '-'} 分 · ${c.moderationReason ?? '涉及金融/负债敏感类目'}', style: const TextStyle(fontSize: 12))),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: XgColors.success, minimumSize: const Size(0, 38)), onPressed: () async {
                        final r = await s.call('POST', '/v1/admin/moderation/${c.contentId}', apiId: 'ADM-C-403', permission: 'content.moderation.approve', body: {'approve': true});
                        if (context.mounted) showApiResult(context, r, successText: '人工通过（2）· 已上线');
                      }, child: const Text('人工通过'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: XgColors.danger, side: const BorderSide(color: XgColors.danger), minimumSize: const Size(0, 38)), onPressed: () async {
                        final r = await s.call('POST', '/v1/admin/moderation/${c.contentId}', apiId: 'ADM-C-403', permission: 'content.moderation.reject', body: {'approve': false, 'reason': '金融违规诱导 / 一般违规'});
                        if (context.mounted) showApiResult(context, r, successText: '已拒绝（3）· Webhook CONTENT.MODERATION.REJECTED');
                      }, child: const Text('拒绝'))),
                    ]),
                  ]),
                ),
              ])),
          if (rejected.isNotEmpty) ...[
            const SectionTitle('已拒绝 · 可申诉'),
            ...rejected.map((c) => ContentCard(c, showModeration: true)),
          ],
          const SectionTitle('AI 初审 12 项维度'),
          const XCard(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              Tag('色情低俗'), Tag('暴力血腥'), Tag('政治敏感'), Tag('涉赌涉毒'), Tag('金融违规诱导', color: XgColors.danger), Tag('虚假宣传', color: XgColors.danger),
              Tag('催收违规话术', color: XgColors.danger), Tag('诱导跳转', color: XgColors.warning), Tag('恶意营销'), Tag('侵权盗用'), Tag('未成年人保护'), Tag('AI 生成未标注', color: XgColors.violet),
            ]),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── API 控制台 ─────────────────────────

class ApiConsolePage extends StatefulWidget {
  const ApiConsolePage({super.key});
  @override
  State<ApiConsolePage> createState() => _ApiConsolePageState();
}

class _ApiConsolePageState extends State<ApiConsolePage> {
  bool _errorsOnly = false;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var logs = s.apiLogs;
    if (_errorsOnly) logs = logs.where((l) => l.code != 0).toList();
    final total = s.apiLogs.length;
    final errs = s.apiLogs.where((l) => l.code != 0).length;
    final avg = total == 0 ? 0 : s.apiLogs.fold(0, (a, l) => a + l.latencyMs) / total;
    final isTab = Navigator.of(context).canPop() == false;
    return Scaffold(
      appBar: isTab
          ? XgAppBar(title: 'API 网关日志', actions: [IconButton(icon: Icon(_errorsOnly ? Icons.error : Icons.error_outline), onPressed: () => setState(() => _errorsOnly = !_errorsOnly))])
          : AppBar(title: const Text('API 网关日志 · 统一响应'), actions: [IconButton(icon: Icon(_errorsOnly ? Icons.error : Icons.error_outline), tooltip: '仅看错误', onPressed: () => setState(() => _errorsOnly = !_errorsOnly))]),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: XgColors.navyDark,
            child: Row(children: [
              _m('请求数', '$total', Colors.white),
              _m('错误', '$errs', errs > 0 ? XgColors.coral : Colors.white),
              _m('成功率', total == 0 ? '-' : '${((total - errs) / total * 100).toStringAsFixed(1)}%', XgColors.gold),
              _m('平均延迟', '${avg.toStringAsFixed(0)} ms', Colors.white),
            ]),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: XgColors.navy,
            child: const Text('{ code, message, trace_id, server_time, data } · 错误码 AABCC · 幂等键 X-Request-Id · APISIX → BFF → 微服务', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
          ),
          Expanded(
            child: logs.isEmpty
                ? const EmptyHint('还没有 API 调用记录', icon: Icons.terminal)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: logs.length,
                    itemBuilder: (_, i) => _LogRow(logs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _m(String l, String v, Color c) => Expanded(child: Column(children: [Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w800)), Text(l, style: const TextStyle(color: Colors.white54, fontSize: 10))]));
}

class _LogRow extends StatelessWidget {
  final ApiLog l;
  const _LogRow(this.l);
  @override
  Widget build(BuildContext context) {
    final ok = l.code == 0;
    final mColor = switch (l.method) {
      'GET' => XgColors.success,
      'POST' => XgColors.info,
      'PATCH' || 'PUT' => XgColors.warning,
      'DELETE' => XgColors.danger,
      _ => XgColors.textSecondary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border(left: BorderSide(color: ok ? XgColors.success : XgColors.danger, width: 3), top: const BorderSide(color: XgColors.divider), right: const BorderSide(color: XgColors.divider), bottom: const BorderSide(color: XgColors.divider))),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 6),
        dense: true,
        shape: const Border(),
        title: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: mColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)), child: Text(l.method, style: TextStyle(color: mColor, fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
          const SizedBox(width: 6),
          Expanded(child: Text(l.path, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
          Text('${l.code}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ok ? XgColors.success : XgColors.danger)),
        ]),
        subtitle: Text('${l.apiId} · ${l.latencyMs} ms · ${l.operator} · ${fmtDate(l.at)}${ok ? '' : ' · ${l.message}'}', style: TextStyle(fontSize: 10, color: ok ? XgColors.textSecondary : XgColors.danger), maxLines: 2),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: XgColors.navyDark, borderRadius: BorderRadius.circular(8)),
            child: Text(
              '// request\nX-Request-Id: ${l.requestId}\nX-Trace-Id: ${l.traceId}\nAuthorization: Bearer eyJ…\n${l.body == null || l.body!.isEmpty ? '' : 'body: ${l.body}\n'}\n// response\n{\n  "code": ${l.code},\n  "message": "${l.message}",\n  "trace_id": "${l.traceId}",\n  "server_time": ${l.at.millisecondsSinceEpoch}\n}',
              style: const TextStyle(color: XgColors.gold, fontFamily: 'monospace', fontSize: 10, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
