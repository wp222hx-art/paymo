import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/agent_service.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'agent_pages.dart';
import 'debt_pages.dart';
import 'debt_points_pages.dart';
import 'shell_page.dart';
import 'task_pages.dart';
import 'wallet_pages.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me;
    final dp = s.myDebtProfile;
    final plans = s.myActivePlans;
    final activeOrders = s.myOrders.where((o) => o.status < 60).toList();
    return Scaffold(
      appBar: const XgAppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── 赎回进度 Hero ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: XCard(
              gradient: XgColors.navyGradient,
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(20),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtCenterPage())),
              child: Row(
                children: [
                  ProgressRing(
                    pct: me.redeemProgressPct,
                    size: 112,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${me.redeemProgressPct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const Text('赎回进度', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('已化解债务', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(fmtMoney(me.carbonDebtSaved), style: const TextStyle(color: XgColors.gold, fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (dp != null) ...[
                          Text('剩余待还 ${fmtMoney(dp.totalDebt)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Text('${dp.debtCount} 笔 · 最长逾期 ${dp.overdueDaysMax} 天', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        ] else
                          const Text('尚未导入负债档案', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 8),
                        Row(children: [
                          _pill(Icons.bolt, '${fmtInt(me.lightPoints)} 光芒值'),
                          const SizedBox(width: 6),
                          _pill(Icons.military_tech_outlined, 'Lv.${me.level}'),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 快捷入口 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _Quick(icon: Icons.explore_outlined, label: 'AI 规划师', color: XgColors.coral, onTap: () => openAgent(context, 'AG-01')),
                _Quick(icon: Icons.work_outline, label: '任务市场', color: XgColors.info, onTap: () => s.setTab(2)),
                _Quick(icon: Icons.token_outlined, label: '债务积分', color: XgColors.gold, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtPointsPage()))),
                _Quick(icon: Icons.shopping_bag_outlined, label: '消费平债', color: XgColors.violet, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OffsetShopPage()))),
              ],
            ),
          ),

          // ── 债务积分池（核心闭环入口）──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.sunrise,
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtPointsPage())),
              child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.token_outlined, color: Colors.white, size: 26)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(s.myAvailablePoints.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const Padding(padding: EdgeInsets.only(left: 4, bottom: 3), child: Text('DP 可用债务积分', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  ]),
                  Text('现金背书 ${fmtMoney(s.myCashBacked)} · 任务/内容/消费/光芒值统一汇入 · 转交银行清缴', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ])),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),

          // ── Agent 头像带（方案二渐变）──
          SectionTitle('8 大 AI Agent · 陪伴者', action: '全部', onAction: () => s.setTab(1)),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: AgentService.agents.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final a = AgentService.agents[i];
                return GestureDetector(
                  onTap: () => openAgent(context, a.code),
                  child: Column(
                    children: [
                      GradientAvatar(a, size: 56),
                      const SizedBox(height: 6),
                      Text(a.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── 今日教练 ──
          SectionTitle('今日 AI 教练'),
          XCard(
            onTap: () => openAgent(context, 'AG-02'),
            child: Row(
              children: [
                GradientAvatar(AgentService.byCode('AG-02'), size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [const Text('赋能教练', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(width: 6), Tag('Claude 3.5', color: XgColors.violet)]),
                      const SizedBox(height: 4),
                      Text(
                        s.myAvailablePoints >= 100
                            ? '连续打卡 23 天 🌱 你的债务积分已有 ${s.myAvailablePoints.toStringAsFixed(0)} DP，今天的小目标：把它们转交银行清缴，让数字变成真实的进度。'
                            : activeOrders.isNotEmpty
                                ? '连续打卡 23 天 🌱 今天的小目标：推进「${s.taskOf(activeOrders.first.taskId).title}」，完成后告诉我。'
                                : '连续打卡 23 天 🌱 今天去任务市场看 1 分钟，不接单也算完成。',
                        style: const TextStyle(fontSize: 12, color: XgColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: XgColors.textSecondary),
              ],
            ),
          ),

          // ── 执行中还款方案 ──
          if (plans.isNotEmpty) ...[
            SectionTitle('执行中的还款方案', action: '债务中心', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtCenterPage()))),
            ...plans.map((p) {
              final c = s.db.debtCases.firstWhere((c) => c.caseId == p.caseId);
              return XCard(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DebtCaseDetailPage(caseId: c.caseId))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(c.creditorName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Tag(p.statusLabel, color: XgColors.success),
                    ]),
                    const SizedBox(height: 4),
                    Text(p.title, style: const TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: p.progress, minHeight: 6, backgroundColor: XgColors.bg, color: XgColors.gold)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text('${p.paidPeriods}/${p.periods} 期', style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      Text('月供 ${fmtMoney(p.monthlyAmount)} · 待还 ${fmtMoney(c.outstanding)}', style: const TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                    ]),
                  ],
                ),
              );
            }),
          ],

          // ── 赎回轨迹 ──
          if (dp != null && dp.weeklySnapshots.length > 2) ...[
            const SectionTitle('赎回轨迹 · 近 10 周负债余额'),
            XCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(fmtMoney(dp.weeklySnapshots.first), style: const TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                    const Icon(Icons.arrow_forward, size: 14, color: XgColors.textSecondary),
                    Text(fmtMoney(dp.totalDebt), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: XgColors.success)),
                    const Spacer(),
                    Tag('-${((1 - dp.totalDebt / dp.weeklySnapshots.first) * 100).toStringAsFixed(1)}%', color: XgColors.success),
                  ]),
                  const SizedBox(height: 8),
                  MiniLineChart(values: dp.weeklySnapshots.map((v) => dp.weeklySnapshots.first - v).toList(), color: XgColors.gold),
                  const SizedBox(height: 4),
                  const Text('snapshot_json 每周快照 · 数据源：DebtProfile', style: TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                ],
              ),
            ),
          ],

          // ── AI 派单推荐 ──
          SectionTitle('AI 派单推荐 · TaskMatcher', action: '更多', onAction: () => s.setTab(2)),
          ...s.marketTasks.where((t) => t.status == 2).take(3).map((t) => TaskCard(task: t, compact: true)),
        ],
      ),
    );
  }

  Widget _pill(IconData i, String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 12, color: XgColors.gold), const SizedBox(width: 3), Text(t, style: const TextStyle(color: Colors.white, fontSize: 11))]),
  );
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Quick({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// AI 价值云页面 U-103
class ValueCloudPage extends StatelessWidget {
  const ValueCloudPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me;
    return Scaffold(
      appBar: AppBar(title: const Text('AI 价值云 · U-103')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          XCard(
            gradient: XgColors.sunrise,
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('综合价值分 value_score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(me.valueScore.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                const Text('用于流量分成权重 · 任务派单排序 · 0~10000', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _vc('embedding_persona', '1536 维', 'MBTI ${me.mbti} + 行为 + 对话')),
                  const SizedBox(width: 8),
                  Expanded(child: _vc('embedding_skills', '1536 维', '任务完成 + 内容创作')),
                  const SizedBox(width: 8),
                  Expanded(child: _vc('embedding_interests', '1536 维', '浏览 / 点赞 / 搜索')),
                ]),
              ],
            ),
          ),
          const SectionTitle('能力标签云 capability_tags'),
          XCard(
            margin: EdgeInsets.zero,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < me.capabilityTags.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: XgColors.agentGradient(i)), borderRadius: BorderRadius.circular(20)),
                    child: Text('${me.capabilityTags[i]}  ${(0.95 - i * 0.09).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SectionTitle('情绪时间轴 emotion_timeline · 近 14 天'),
          XCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                MiniLineChart(values: const [42, 38, 45, 52, 48, 60, 58, 66, 62, 70, 68, 74, 72, 78], color: XgColors.violet, height: 80),
                const SizedBox(height: 6),
                const Row(children: [Text('低落', style: TextStyle(fontSize: 10, color: XgColors.textSecondary)), Spacer(), Text('由赋能教练对话 + 打卡记录推断 · 趋势向好 ↑', style: TextStyle(fontSize: 10, color: XgColors.textSecondary))]),
              ],
            ),
          ),
          const SectionTitle('成长体系 U-104'),
          XCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                KV('等级 / 经验', 'Lv.${me.level} · ${me.exp}/${me.level * 400} EXP'),
                KV('光芒值', '${fmtInt(me.lightPoints)}（100 光芒值 = ¥1 还债额度）'),
                KV('信用重塑分', '${me.creditScore}（履约分驱动）'),
                KV('勋章', '🏅 首单达成 · 🔥 连续打卡 20 天 · 💎 流量还债 ¥1000+'),
                KV('邀请码', me.inviteCode),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final r = await s.call('POST', '/v1/users/me/value-cloud/recompute', apiId: 'API-U-007', requestId: 'recompute-${me.userId}-${DateTime.now().day}');
              if (context.mounted) showApiResult(context, r, successText: r.idempotencyReplay ? '今日已重算（幂等返回首次结果）' : '价值云重算完成 · value_score → ${r.data?['value_score']}');
            },
            icon: const Icon(Icons.refresh),
            label: const Text('手动触发价值云重算 · API-U-007（每日限 1 次）'),
          ),
        ],
      ),
    );
  }

  Widget _vc(String k, String v, String d) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      Text(d, style: const TextStyle(color: Colors.white70, fontSize: 9)),
    ]),
  );
}

/// 商家工作台
class MerchantHomePage extends StatelessWidget {
  const MerchantHomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me;
    final tasks = s.myPublishedTasks;
    final pendingReview = s.db.orders.where((o) => tasks.any((t) => t.taskId == o.taskId) && o.status == OrderStatus.awaitingReview).toList();
    final disputes = s.db.orders.where((o) => tasks.any((t) => t.taskId == o.taskId) && o.status == OrderStatus.dispute).toList();
    return Scaffold(
      appBar: const XgAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          XCard(
            gradient: XgColors.navyGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('商家账户 · L5 企业认证', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(fmtMoney(me.walletBalance), style: const TextStyle(color: XgColors.gold, fontSize: 28, fontWeight: FontWeight.w800)),
                Text('保证金冻结 ${fmtMoney(me.walletFrozen)} · 单日限额 ${fmtMoney(KycLevel.limits[5])}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: FilledButton.tonal(style: FilledButton.styleFrom(backgroundColor: XgColors.gold, foregroundColor: XgColors.navyDark), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishTaskPage())), child: const Text('发布任务'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())), child: const Text('充值 / 流水'))),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              StatTile(label: '在投任务', value: '${tasks.where((t) => t.status == 2 || t.status == 3).length}', icon: Icons.campaign_outlined),
              const SizedBox(width: 8),
              StatTile(label: '待验收', value: '${pendingReview.length}', icon: Icons.pending_actions_outlined, color: XgColors.warning),
              const SizedBox(width: 8),
              StatTile(label: '争议中', value: '${disputes.length}', icon: Icons.gavel_outlined, color: XgColors.danger),
            ]),
          ),
          if (pendingReview.isNotEmpty) ...[
            const SectionTitle('待验收交付物 · API-T-006'),
            ...pendingReview.map((o) => OrderCard(order: o, merchantView: true)),
          ],
          if (disputes.isNotEmpty) ...[
            const SectionTitle('争议中 · 等待平台仲裁'),
            ...disputes.map((o) => OrderCard(order: o, merchantView: true)),
          ],
          const SectionTitle('我发布的任务 · API-T-008'),
          if (tasks.isEmpty) const EmptyHint('还没有发布任务'),
          ...tasks.map((t) => TaskCard(task: t)),
          const SectionTitle('AI 商业助手'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _agentBtn(context, 'AG-03', '一键 AI 匹配候选人')),
              const SizedBox(width: 10),
              Expanded(child: _agentBtn(context, 'AG-04', '生成品牌 Brief 文案')),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _agentBtn(BuildContext c, String code, String label) {
    final a = AgentService.byCode(code);
    return XCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      onTap: () => openAgent(c, code),
      child: Row(children: [GradientAvatar(a, size: 36), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))]),
    );
  }
}
