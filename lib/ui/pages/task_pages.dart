import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'agent_pages.dart';
import 'shell_page.dart';

class TaskMarketPage extends StatefulWidget {
  const TaskMarketPage({super.key});
  @override
  State<TaskMarketPage> createState() => _TaskMarketPageState();
}

class _TaskMarketPageState extends State<TaskMarketPage> {
  String _filter = '全部';
  Map<String, int> _match = {};
  bool _loadingAi = false;

  Future<void> _aiRecommend() async {
    setState(() => _loadingAi = true);
    final r = await context.read<AppState>().call('POST', '/v1/tasks/ai/recommend', apiId: 'API-T-010');
    if (!mounted) return;
    setState(() {
      _loadingAi = false;
      if (r.ok) {
        _match = {for (final e in (r.data['recommendations'] as List)) e['task_id'] as String: e['match_score'] as int};
      }
    });
    showApiResult(context, r, successText: 'AG-03 TaskMatcher 已完成向量匹配 · ${r.data?['model']}');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final isMerchant = s.me.role == UserRole.merchant;
    final isOps = s.me.role == UserRole.opsManager;
    var tasks = isOps ? s.db.tasks : s.marketTasks;
    if (_filter != '全部') tasks = tasks.where((t) => t.taskType == _filter).toList();
    if (_match.isNotEmpty) tasks = [...tasks]..sort((a, b) => (_match[b.taskId] ?? 0).compareTo(_match[a.taskId] ?? 0));
    final myOrders = s.myOrders;
    return Scaffold(
      appBar: XgAppBar(title: isOps ? '任务运营 · OP-103' : '任务市场 · D05', actions: [
        if (isMerchant) IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishTaskPage()))),
      ]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (!isMerchant && !isOps)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: XCard(
                margin: EdgeInsets.zero,
                gradient: XgColors.sunrise,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Text('🎯', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI 派单 · T-502', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('基于价值云 Embedding 匹配 Top-N 任务', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ])),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: XgColors.violet, minimumSize: const Size(0, 36)),
                    onPressed: _loadingAi ? null : _aiRecommend,
                    child: _loadingAi ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('智能匹配'),
                  ),
                ]),
              ),
            ),
          if (myOrders.isNotEmpty && !isMerchant && !isOps) ...[
            SectionTitle('我接的单 · API-T-009（${myOrders.length}）'),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: myOrders.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final o = myOrders[i];
                  final t = s.taskOf(o.taskId);
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.orderId))),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: orderStatusColor(o.status).withValues(alpha: 0.5))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Tag(OrderStatus.label(o.status), color: orderStatusColor(o.status)), const Spacer(), Text(o.orderId, style: const TextStyle(fontSize: 10, color: XgColors.textSecondary))]),
                        const SizedBox(height: 6),
                        Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${fmtMoney(t.rewardAmount)} · ${t.splitPolicy.label}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
          const SectionTitle('任务广场 · API-T-003'),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['全部', '内容创作', '推广', '调研', '客服', '技能服务'].map((f) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f), selectedColor: XgColors.navy, labelStyle: TextStyle(color: _filter == f ? Colors.white : XgColors.textPrimary, fontSize: 12)))).toList(),
            ),
          ),
          const SizedBox(height: 10),
          ...tasks.map((t) => TaskCard(task: t, matchScore: _match[t.taskId])),
        ],
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final bool compact;
  final int? matchScore;
  const TaskCard({super.key, required this.task, this.compact = false, this.matchScore});
  @override
  Widget build(BuildContext context) {
    final t = task;
    final me = context.read<AppState>().me;
    final locked = me.kycLevel < t.kycLevelRequired || me.valueScore < t.valueScoreMin;
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: t.taskId))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Tag(t.taskType, color: XgColors.info),
          const SizedBox(width: 4),
          Tag(t.statusLabel, color: t.status == 2 ? XgColors.success : (t.status == 1 ? XgColors.warning : XgColors.textSecondary)),
          if (matchScore != null) ...[const SizedBox(width: 4), Tag('匹配 $matchScore%', color: XgColors.coral, icon: Icons.auto_awesome)],
          const Spacer(),
          Text(fmtMoney(t.rewardAmount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: XgColors.navy)),
        ]),
        const SizedBox(height: 8),
        Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(t.description, style: const TextStyle(fontSize: 12, color: XgColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.storefront_outlined, size: 13, color: XgColors.textSecondary),
          const SizedBox(width: 3),
          Text(t.publisherName, style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          const SizedBox(width: 10),
          const Icon(Icons.people_outline, size: 13, color: XgColors.textSecondary),
          const SizedBox(width: 3),
          Text('${t.currentParticipants}/${t.maxParticipants}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          const Spacer(),
          Text(t.splitPolicy.label, style: const TextStyle(fontSize: 10, color: XgColors.success, fontWeight: FontWeight.w600)),
        ]),
        if (locked && !compact) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.lock_outline, size: 12, color: XgColors.warning),
            const SizedBox(width: 4),
            Text('门槛：${KycLevel.name(t.kycLevelRequired)} · 价值分 ≥ ${t.valueScoreMin}', style: const TextStyle(fontSize: 10, color: XgColors.warning)),
          ]),
        ],
      ]),
    );
  }
}

class TaskDetailPage extends StatelessWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.taskOf(taskId);
    final me = s.me;
    final myOrder = s.myOrders.where((o) => o.taskId == taskId).firstOrNull;
    final isPublisher = t.publisherId == me.userId;
    final orders = s.ordersForTask(taskId);
    return Scaffold(
      appBar: AppBar(title: const Text('任务详情 · API-T-002')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          XCard(
            margin: EdgeInsets.zero,
            gradient: XgColors.navyGradient,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Tag(t.taskType, color: Colors.white, bg: Colors.white.withValues(alpha: 0.2)), const SizedBox(width: 6), Tag(t.statusLabel, color: XgColors.gold, bg: XgColors.gold.withValues(alpha: 0.2))]),
              const SizedBox(height: 10),
              Text(t.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(children: [
                Text(fmtMoney(t.rewardAmount), style: const TextStyle(color: XgColors.gold, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text(['', '固定', '阶梯', '竞价'][t.rewardType], style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Text('分账策略：${t.splitPolicy.label}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 12),
          XCard(
            margin: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('任务描述', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(t.description, style: const TextStyle(fontSize: 13, height: 1.5)),
              const Divider(height: 20),
              KV('发布方', t.publisherName),
              KV('名额', '${t.currentParticipants}/${t.maxParticipants}'),
              KV('KYC 门槛', KycLevel.name(t.kycLevelRequired), vColor: me.kycLevel >= t.kycLevelRequired ? XgColors.success : XgColors.danger),
              KV('价值分门槛', '≥ ${t.valueScoreMin}（你：${me.valueScore.toStringAsFixed(0)}）', vColor: me.valueScore >= t.valueScoreMin ? XgColors.success : XgColors.danger),
              KV('目标标签', t.targetTags.isEmpty ? '不限' : t.targetTags.join(' / ')),
              KV('截止', fmtDay(t.deadlineAt)),
              KV('商家保证金', fmtMoney(t.depositAmount)),
              KV('归因', 'UTM 短链 · 点击 7d / 转化 30d · 末次点击'),
            ]),
          ),
          const SizedBox(height: 12),
          if (isPublisher || me.role.isAdmin) ...[
            Text('接单订单（${orders.length}）', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (orders.isEmpty) const EmptyHint('暂无接单'),
            ...orders.map((o) => OrderCard(order: o, merchantView: true)),
            if (isPublisher)
              OutlinedButton.icon(
                onPressed: () async {
                  final r = await s.call('POST', '/v1/tasks/${t.taskId}/ai/match', apiId: 'API-T-011', permission: 'task.ai.match');
                  if (context.mounted) showApiResult(context, r, successText: 'AI 已匹配候选人：林晓明 92% · 苏雨桐 88% · 已发送邀请');
                },
                icon: const Text('🎯'),
                label: const Text('一键 AI 匹配候选人 · API-T-011'),
              ),
          ] else if (myOrder != null) ...[
            FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: myOrder.orderId))), child: Text('查看我的订单 · ${OrderStatus.label(myOrder.status)}')),
          ] else ...[
            FilledButton(
              onPressed: t.status != 2
                  ? null
                  : () async {
                      final r = await s.call('POST', '/v1/tasks/${t.taskId}/accept', apiId: 'API-T-004', requestId: 'accept-${t.taskId}-${me.userId}', body: {'task_id': t.taskId});
                      if (!context.mounted) return;
                      showApiResult(context, r, successText: '接单成功 · 订单 ${r.data?['order_id']} 已进入执行中');
                      if (r.ok) Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: r.data['order_id'])));
                    },
              child: const Text('立即接单 · API-T-004'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => openAgent(context, 'AG-03'), icon: const Text('🎯'), label: const Text('让接单助手写投递话术')),
          ],
        ],
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final TaskOrder order;
  final bool merchantView;
  const OrderCard({super.key, required this.order, this.merchantView = false});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final t = s.taskOf(order.taskId);
    final worker = s.db.users[order.userId];
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: order.orderId))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Tag(OrderStatus.label(order.status), color: orderStatusColor(order.status)),
          const SizedBox(width: 6),
          Text(order.orderId, style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          const Spacer(),
          Text(fmtMoney(t.rewardAmount), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text(t.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (merchantView && worker != null) ...[
          const SizedBox(height: 4),
          Row(children: [Avatar(worker, size: 18), const SizedBox(width: 6), Text('${worker.nickname} · ${KycLevel.name(worker.kycLevel)} · 履约 ${worker.creditScore}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary))]),
        ],
        if (order.aiCheckScore != null) ...[
          const SizedBox(height: 4),
          Text('AI 初验原创性 ${order.aiCheckScore!.toStringAsFixed(1)} · 尝试 ${order.aiCheckAttempts}/3', style: TextStyle(fontSize: 11, color: order.aiCheckScore! >= 60 ? XgColors.success : XgColors.danger)),
        ],
      ]),
    );
  }
}

class OrderDetailPage extends StatelessWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final o = s.db.orders.firstWhere((o) => o.orderId == orderId);
    final t = s.taskOf(o.taskId);
    final me = s.me;
    final isWorker = o.userId == me.userId;
    final isPublisher = t.publisherId == me.userId;
    final failed = [31, 32, 55, 70, 81].contains(o.status);
    final flowCurrent = OrderStatus.flow.contains(o.status) ? o.status : (o.status == 55 || o.status == 70 ? 50 : (o.status == 81 ? 60 : 20));
    final st = o.settlementId == null ? null : s.db.settlements.where((x) => x.settlementId == o.settlementId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text('订单 ${o.orderId}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          XCard(
            margin: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700))), Tag(OrderStatus.label(o.status), color: orderStatusColor(o.status))]),
              const SizedBox(height: 14),
              StateFlow(steps: OrderStatus.flow, current: flowCurrent, label: OrderStatus.label, failed: failed),
              if (failed) ...[const SizedBox(height: 8), Text('当前分支状态：${OrderStatus.label(o.status)}', style: const TextStyle(fontSize: 12, color: XgColors.danger, fontWeight: FontWeight.w600))],
              const Divider(height: 20),
              KV('奖励', '${fmtMoney(t.rewardAmount)} · ${t.splitPolicy.label}'),
              KV('接单人', s.db.users[o.userId]?.nickname ?? o.userId),
              KV('发布方', t.publisherName),
              KV('截止', fmtDay(t.deadlineAt)),
              if (o.submission != null) KV('交付物', o.submission!),
              if (o.aiCheckScore != null) KV('AI 初验', '原创性 ${o.aiCheckScore!.toStringAsFixed(1)} / 60 · 第 ${o.aiCheckAttempts} 次', vColor: o.aiCheckScore! >= 60 ? XgColors.success : XgColors.danger),
            ]),
          ),
          const SizedBox(height: 12),
          if (st != null)
            XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.sunrise,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('结算单 ${st.settlementId} · T-506 自动分账', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(children: [
                  _sp('总额', st.gross),
                  _sp('→ 流量还债', st.repayPart),
                  _sp('→ 钱包', st.cashPart),
                  _sp('平台费', st.platformFee),
                ]),
                const SizedBox(height: 8),
                const Text('Webhook：TASK.ORDER.COMPLETED · SETTLEMENT.CREATED → 商家', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ),
          if (st != null) const SizedBox(height: 12),

          // ── 操作区 ──
          if (isWorker && o.status == OrderStatus.executing) _SubmitBox(o: o),
          if (isPublisher && o.status == OrderStatus.awaitingReview) _ReviewBox(o: o, t: t),
          if (me.role.isAdmin && o.status == OrderStatus.dispute) _ArbitrateBox(o: o, t: t),
          if (isWorker && o.status == OrderStatus.awaitingReview)
            XCard(margin: EdgeInsets.zero, padding: const EdgeInsets.all(12), child: const Row(children: [Icon(Icons.hourglass_top, color: XgColors.warning, size: 18), SizedBox(width: 8), Expanded(child: Text('AI 初验已通过，等待商家验收。商家 72h 内未响应将自动通过（→ 60 已通过）。', style: TextStyle(fontSize: 12)))])),
          if (isWorker && o.status == OrderStatus.dispute)
            XCard(margin: EdgeInsets.zero, padding: const EdgeInsets.all(12), child: const Row(children: [Icon(Icons.gavel, color: XgColors.danger, size: 18), SizedBox(width: 8), Expanded(child: Text('商家拒绝验收，订单进入争议中。平台将在 48h 内仲裁，保证金按仲裁结果分配。', style: TextStyle(fontSize: 12)))])),

          const SizedBox(height: 12),
          const Text('状态迁移审计 task_order_history', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          XCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: o.history.reversed.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: orderStatusColor(h.to), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${h.from == 0 ? '—' : OrderStatus.label(h.from)} → ${OrderStatus.label(h.to)}  ·  ${h.reasonCode}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('${h.operator} · ${fmtDate(h.at)}${h.evidence.isNotEmpty ? ' · ${h.evidence}' : ''}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                      ])),
                    ]),
                  )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sp(String l, double v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10)), Text(fmtMoney(v), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))]));
}

class _SubmitBox extends StatefulWidget {
  final TaskOrder o;
  const _SubmitBox({required this.o});
  @override
  State<_SubmitBox> createState() => _SubmitBoxState();
}

class _SubmitBoxState extends State<_SubmitBox> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    return XCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('提交交付物 · API-T-005', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('提交后触发 AI 初验（原创性 / 搬运检测 / AIGC 标注）。< 60 分退回修改，最多 3 次。提示：含"搬运/测试"字样会被判低分。', style: TextStyle(fontSize: 11, color: XgColors.textSecondary)),
        const SizedBox(height: 10),
        TextField(controller: _ctrl, minLines: 2, maxLines: 4, decoration: const InputDecoration(hintText: '作品链接 / 凭证说明，例如：https://v.douyin.com/xxx 已挂归因短链')),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final s = context.read<AppState>();
                  final r = await s.call('POST', '/v1/tasks/${widget.o.taskId}/orders/${widget.o.orderId}/submit', apiId: 'API-T-005', body: {'submission': _ctrl.text});
                  if (!context.mounted) return;
                  setState(() => _busy = false);
                  showApiResult(context, r, successText: r.data?['message'] ?? 'AI 初验通过（${(r.data?['ai_score'] as num?)?.toStringAsFixed(1)}）→ 待商家验收');
                },
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('提交并触发 AI 初验'),
        ),
      ]),
    );
  }
}

class _ReviewBox extends StatelessWidget {
  final TaskOrder o;
  final Task t;
  const _ReviewBox({required this.o, required this.t});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return XCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('商家验收 · API-T-006', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('通过后立即结算：¥${t.rewardAmount.toStringAsFixed(0)} 从保证金划出，按 ${t.splitPolicy.label} 分账并生成 4 条复式分录。', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: XgColors.success),
              onPressed: () async {
                final r = await s.call('POST', '/v1/tasks/${t.taskId}/orders/${o.orderId}/review', apiId: 'API-T-006', permission: 'task.review', requestId: 'review-${o.orderId}', body: {'approve': true});
                if (context.mounted) showApiResult(context, r, successText: '验收通过 · 已结算 ${r.data?['settlement_id']}');
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('通过并结算'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: XgColors.danger, side: const BorderSide(color: XgColors.danger)),
              onPressed: () async {
                final r = await s.call('POST', '/v1/tasks/${t.taskId}/orders/${o.orderId}/review', apiId: 'API-T-006', permission: 'task.review', body: {'approve': false, 'reason': '交付物与 Brief 不符'});
                if (context.mounted) showApiResult(context, r, successText: '已拒绝 → 争议中 · ${r.data?['arbitration']}');
              },
              icon: const Icon(Icons.close, size: 18),
              label: const Text('拒绝'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ArbitrateBox extends StatelessWidget {
  final TaskOrder o;
  final Task t;
  const _ArbitrateBox({required this.o, required this.t});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return XCard(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('平台仲裁 · T-508 争议仲裁', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: XgColors.success), onPressed: () async {
            final r = await s.call('POST', '/v1/tasks/${t.taskId}/orders/${o.orderId}/arbitrate', apiId: 'API-T-007', body: {'approve': true, 'reason': 'AI 初验 ${o.aiCheckScore} 分 + 交付物符合 Brief'});
            if (context.mounted) showApiResult(context, r, successText: '仲裁支持接单人 → 已结算');
          }, child: const Text('支持接单人'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: XgColors.danger, side: const BorderSide(color: XgColors.danger)), onPressed: () async {
            final r = await s.call('POST', '/v1/tasks/${t.taskId}/orders/${o.orderId}/arbitrate', apiId: 'API-T-007', body: {'approve': false, 'reason': '交付物不符'});
            if (context.mounted) showApiResult(context, r, successText: '仲裁支持商家 → 已终止，保证金退回');
          }, child: const Text('支持商家'))),
        ]),
      ]),
    );
  }
}

class PublishTaskPage extends StatefulWidget {
  const PublishTaskPage({super.key});
  @override
  State<PublishTaskPage> createState() => _PublishTaskPageState();
}

class _PublishTaskPageState extends State<PublishTaskPage> {
  final _title = TextEditingController(text: '「星辰晨露精华」小红书图文种草（第二批）');
  final _desc = TextEditingController(text: '撰写 500 字以上真实体验图文，突出敏感肌友好，挂平台归因短链，需保留原始素材 30 天。');
  final _reward = TextEditingController(text: '260');
  final _max = TextEditingController(text: '20');
  String _type = '内容创作';
  int _kyc = 2;
  double _repay = 60;
  final Set<String> _tags = {'图文种草', '美妆'};

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final deposit = (double.tryParse(_reward.text) ?? 0) * (int.tryParse(_max.text) ?? 0);
    return Scaffold(
      appBar: AppBar(title: const Text('发布任务 · API-T-001')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: '任务标题（≤120）')),
          const SizedBox(height: 10),
          TextField(controller: _desc, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: '任务描述')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _type,
            items: ['内容创作', '推广', '调研', '客服', '技能服务', '线下探店'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _type = v!),
            decoration: const InputDecoration(labelText: '任务类型'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _reward, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: '单人奖励（元）'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: '最大人数'))),
          ]),
          const SizedBox(height: 14),
          Text('最低 KYC 等级：${KycLevel.name(_kyc)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Slider(value: _kyc.toDouble(), min: 1, max: 4, divisions: 3, onChanged: (v) => setState(() => _kyc = v.round())),
          Text('默认分账策略：还债 ${_repay.round()}% / 提现 ${100 - _repay.round()}%（接单人可改）', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Slider(value: _repay, min: 0, max: 100, divisions: 10, activeColor: XgColors.gold, onChanged: (v) => setState(() => _repay = v)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: ['图文种草', '美妆', '短视频剪辑', '本地生活', '客服沟通', '私域运营', '文案写作'].map((t) => FilterChip(label: Text(t, style: const TextStyle(fontSize: 12)), selected: _tags.contains(t), onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t)))).toList()),
          const SizedBox(height: 16),
          XCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Text('需缴纳保证金', style: TextStyle(fontSize: 13)), const Spacer(), Text(fmtMoney(deposit), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: XgColors.navy))]),
              Text('当前可用 ${fmtMoney(s.me.walletBalance)} · 保证金冻结至任务结算 · 提交后进入运营审核（OP-103）', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final r = await s.call('POST', '/v1/tasks', apiId: 'API-T-001', kycRequired: 2, permission: 'task.publish', requestId: 'pub-${_title.text.hashCode}', body: {
                'title': _title.text,
                'description': _desc.text,
                'task_type': _type,
                'reward_amount': double.tryParse(_reward.text) ?? 0,
                'max_participants': int.tryParse(_max.text) ?? 0,
                'kyc_level_required': _kyc,
                'repay_pct': _repay.round(),
                'cash_pct': 100 - _repay.round(),
                'target_tags': _tags.toList(),
              });
              if (!context.mounted) return;
              showApiResult(context, r, successText: '任务 ${r.data?['task_id']} 已提交 · 保证金 ${fmtMoney(r.data?['deposit_amount'] ?? 0)} 已冻结 · 审核中');
              if (r.ok) Navigator.pop(context);
            },
            child: const Text('发布任务并缴纳保证金'),
          ),
        ],
      ),
    );
  }
}
