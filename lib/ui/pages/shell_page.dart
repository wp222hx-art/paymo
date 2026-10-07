import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../admin/admin_pages.dart';
import '../admin/offset_rules_page.dart';
import '../bank/bank_pages.dart';
import '../../core/module_info.dart';
import '../widgets/common.dart';
import '../widgets/module_widgets.dart';
import 'agent_pages.dart';
import 'community_page.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'task_pages.dart';

class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me;
    final List<(Widget, NavigationDestination)> tabs;
    if (me.role == UserRole.bankOfficer) {
      tabs = [
        (const BankQueuePage(), const NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: '受理队列')),
        (const BankCasesPage(), const NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: '本行案件')),
        (const ApiConsolePage(), const NavigationDestination(icon: Icon(Icons.terminal_outlined), selectedIcon: Icon(Icons.terminal), label: 'API 日志')),
        (const AgentHubPage(), const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI')),
        (const ProfilePage(), const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的')),
      ];
    } else if (me.role == UserRole.riskOfficer) {
      tabs = [
        (const RiskDashboardPage(), const NavigationDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: '风控台')),
        (const RiskRulesPage(), const NavigationDestination(icon: Icon(Icons.rule_folder_outlined), selectedIcon: Icon(Icons.rule_folder), label: '规则引擎')),
        (const ApiConsolePage(), const NavigationDestination(icon: Icon(Icons.terminal_outlined), selectedIcon: Icon(Icons.terminal), label: 'API 日志')),
        (const AgentHubPage(), const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI')),
        (const ProfilePage(), const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的')),
      ];
    } else if (me.role == UserRole.opsManager) {
      tabs = [
        (const OpsDashboardPage(), const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '看板')),
        (const ModerationPage(), const NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: '内容审核')),
        (const OffsetRulesPage(), const NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: '倍率规则')),
        (const TaskMarketPage(), const NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: '任务')),
        (const ProfilePage(), const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的')),
      ];
    } else if (me.role == UserRole.merchant) {
      tabs = [
        (const MerchantHomePage(), const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: '工作台')),
        (const TaskMarketPage(), const NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: '任务')),
        (const AgentHubPage(), const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI')),
        (const CommunityPage(), const NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: '社区')),
        (const ProfilePage(), const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的')),
      ];
    } else {
      tabs = [
        (const HomePage(), const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页')),
        (const AgentHubPage(), const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI')),
        (const TaskMarketPage(), const NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: '任务')),
        (const CommunityPage(), const NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: '社区')),
        (const ProfilePage(), const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的')),
      ];
    }
    final idx = s.tabIndex.clamp(0, tabs.length - 1);
    return Scaffold(
      body: IndexedStack(index: idx, children: tabs.map((t) => t.$1).toList()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: s.setTab,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: tabs.map((t) => t.$2).toList(),
      ),
    );
  }
}

/// 顶部通用 AppBar：头像 + 角色切换 + 通知
class XgAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final ModuleInfo? info;
  const XgAppBar({super.key, this.title, this.actions, this.info});
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me;
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: GestureDetector(onTap: () => showUserSwitcher(context), child: Center(child: Avatar(me, size: 34))),
      ),
      leadingWidth: 56,
      title: GestureDetector(
        onTap: () => showUserSwitcher(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title ?? me.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: XgColors.gold, borderRadius: BorderRadius.circular(4)),
                    child: Text(me.role.label, style: const TextStyle(fontSize: 10, color: XgColors.navyDark, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Text(KycLevel.name(me.kycLevel), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  const Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
                ]),
              ],
            ),
          ],
        ),
      ),
      actions: [
        ...?actions,
        if (info != null) InfoButton(info!),
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => _showNotifications(context)),
            if (s.unread > 0)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: XgColors.coral, shape: BoxShape.circle),
                  child: Text('${s.unread}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    showXSheet(
      context,
      title: '通知中心 · N-806',
      Consumer<AppState>(
        builder: (_, s, __) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Text('系统 / 互动 / 任务 / 金融 四类订阅', style: TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                const Spacer(),
                TextButton(onPressed: () => s.call('POST', '/v1/notifications/read-all', apiId: 'API-N-011'), child: const Text('全部已读', style: TextStyle(fontSize: 12))),
              ],
            ),
            ...s.notifications.map((n) {
              final icon = switch (n.category) {
                'finance' => Icons.account_balance_wallet_outlined,
                'task' => Icons.work_outline,
                'interact' => Icons.favorite_border,
                _ => Icons.campaign_outlined,
              };
              final col = switch (n.category) {
                'finance' => XgColors.success,
                'task' => XgColors.info,
                'interact' => XgColors.coral,
                _ => XgColors.violet,
              };
              return XCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                onTap: () {
                  n.read = true;
                  s.refresh();
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: col, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w400 : FontWeight.w700, fontSize: 13))),
                            if (!n.read) Container(width: 8, height: 8, decoration: const BoxDecoration(color: XgColors.coral, shape: BoxShape.circle)),
                          ]),
                          const SizedBox(height: 4),
                          Text(n.body, style: const TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(fmtDate(n.at), style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 多用户切换面板
void showUserSwitcher(BuildContext context) {
  final s = context.read<AppState>();
  showXSheet(
    context,
    title: '切换身份',
    ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        const Text('同一套后端数据，不同角色看到不同的首页、权限点与 API 可用范围。切换将吊销当前 Token（API-A-008）并颁发新会话。', style: TextStyle(fontSize: 12, color: XgColors.textSecondary)),
        const SizedBox(height: 12),
        ...s.allUsers.map((u) {
          final current = u.userId == s.me.userId;
          return XCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            onTap: current
                ? null
                : () async {
                    Navigator.pop(context);
                    await s.switchUser(u.userId);
                  },
            child: Row(
              children: [
                Avatar(u, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(u.nickname, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Tag(u.role.label, color: u.role.isBank ? XgColors.success : (u.role.isAdmin ? XgColors.violet : XgColors.navy)),
                        if (u.status != UserStatus.normal) ...[const SizedBox(width: 4), Tag(u.status.label, color: XgColors.danger)],
                      ]),
                      const SizedBox(height: 3),
                      Text('${u.orgName ?? u.role.desc} · ${KycLevel.name(u.kycLevel)} · ${u.city}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
                      const SizedBox(height: 3),
                      Text('权限点 ${u.permissions.length} 个：${u.permissions.take(3).join(', ')}…', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                    ],
                  ),
                ),
                if (current) const Icon(Icons.check_circle, color: XgColors.success) else const Icon(Icons.chevron_right, color: XgColors.textSecondary),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            s.logout();
          },
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('退出登录'),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}
