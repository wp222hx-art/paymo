import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/mall_state.dart';
import '../widgets/common.dart';
import 'account_pages.dart';
import 'clear_pages.dart';
import 'labor_pages.dart';
import 'mall_order_pages.dart';
import 'mall_pages.dart';
import 'mall_widgets.dart';
import 'staff_pages.dart' show showRoleSwitcher;

/// C 端主框架：首页 / 微劳动 / 清偿 / 购物车 / 我的
class MallShell extends StatelessWidget {
  const MallShell({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final idx = m.tab.clamp(0, 4);
    const pages = [MallHomePage(), LaborHomePage(embedded: true), ClearCenterPage(embedded: true), CartPage(embedded: true), MinePage()];
    return Theme(
      data: Theme.of(context).copyWith(scaffoldBackgroundColor: Sx.bg, colorScheme: Theme.of(context).colorScheme.copyWith(primary: Sx.ink)),
      child: Scaffold(
        body: IndexedStack(index: idx, children: pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(color: Colors.white, boxShadow: Sx.shadow(0.05)),
          child: SafeArea(
            child: SizedBox(
              height: 60,
              child: Row(children: [
                _tab(m, 0, idx, Icons.home_rounded, Icons.home_outlined, '首页'),
                _tab(m, 1, idx, Icons.work_rounded, Icons.work_outline_rounded, '微劳动', badge: toI(m.laborSummary?['active'])),
                Expanded(child: GestureDetector(
                  onTap: () => m.setTab(2),
                  behavior: HitTestBehavior.opaque,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 44,
                      height: 30,
                      decoration: BoxDecoration(gradient: idx == 2 ? Sx.goldGrad : null, color: idx == 2 ? null : Sx.ink, borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.eco_rounded, color: Colors.white, size: 19),
                    ),
                    const SizedBox(height: 3),
                    Text('清偿', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: idx == 2 ? Sx.gold : Sx.ink)),
                  ]),
                )),
                _tab(m, 3, idx, Icons.shopping_bag_rounded, Icons.shopping_bag_outlined, '购物车', badge: m.cartCount),
                _tab(m, 4, idx, Icons.person_rounded, Icons.person_outline_rounded, '我的', badge: toI(m.overview?['unread_letters'])),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(MallState s, int i, int cur, IconData on, IconData off, String label, {int badge = 0}) => Expanded(
        child: InkWell(
          onTap: () => s.setTab(i),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Badge(isLabelVisible: badge > 0, label: Text('$badge'), backgroundColor: Sx.coral, child: Icon(cur == i ? on : off, color: cur == i ? Sx.ink : Sx.muted, size: 24)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: cur == i ? FontWeight.w800 : FontWeight.w500, color: cur == i ? Sx.ink : Sx.muted)),
          ]),
        ),
      );
}

/// 我的
class MinePage extends StatelessWidget {
  const MinePage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final ov = m.overview ?? const {};
    final bal = (ov['balance'] as Map?) ?? const {};
    final ls = m.laborSummary ?? const {};
    final top = MediaQuery.of(context).padding.top;
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    final name = '${m.me?['nickname'] ?? ''}';
    return Scaffold(
      backgroundColor: Sx.bg,
      body: MallGate(builder: (ctx, m) => ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, top + 18, 12, 70),
          decoration: const BoxDecoration(gradient: Sx.heroGrad),
          child: Row(children: [
            CircleAvatar(radius: 29, backgroundColor: Sx.gold, child: Text(name.isEmpty ? '?' : name.characters.first, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                SPill('Lv.${ls['level'] ?? 1}', color: Sx.gold, bg: Colors.white12),
              ]),
              const SizedBox(height: 4),
              Text('${m.me?['mobile'] ?? ''} · 信用 ${ov['credit_score'] ?? '-'} · ${['', '手机认证', '实名认证', '活体认证', '银行卡认证'][toI(ls['kyc']).clamp(1, 4)]}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            IconButton(tooltip: '切换演示身份', onPressed: () => showRoleSwitcher(context), icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white70)),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -52),
          child: Column(children: [
            SCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                _num('可用清偿金', fmtMoney(toD(bal['available'])), () => m.setTab(2)),
                _num('钱包余额', fmtMoney(toD(m.me?['wallet_balance'])), () => go(const WalletPage())),
                _num('微劳动收入', fmtMoney(toD(ls['cash']) + toD(ls['clear'])), () => go(const MyTasksPage())),
              ]),
            ),
            SCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(children: [
                Row(children: [const Text('我的订单', style: Sx.h3), const Spacer(), GestureDetector(onTap: () => go(const MallOrdersPage()), child: const Text('全部 ›', style: Sx.small))]),
                const SizedBox(height: 14),
                Row(children: [
                  _ord(context, Icons.payment_rounded, '待支付', 1),
                  _ord(context, Icons.inventory_2_rounded, '待发货', 2),
                  _ord(context, Icons.local_shipping_rounded, '待收货', 3),
                  _ord(context, Icons.task_alt_rounded, '已完成', 4),
                  _ord(context, Icons.support_agent_rounded, '售后', 5),
                ]),
              ]),
            ),
            SCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                _item(Icons.assignment_rounded, '我的任务', toI(ls['active']) > 0 ? '${ls['active']} 个进行中' : '已完成 ${ls['done'] ?? 0} 单', () => go(const MyTasksPage())),
                _item(Icons.account_balance_wallet_rounded, '钱包 · 收益与提现', '现金收益可提现', () => go(const WalletPage())),
                _item(Icons.verified_user_rounded, '实名与安全', '解锁更多任务与提现', () => go(const KycPage()), last: true),
              ]),
            ),
            SCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                _item(Icons.account_balance_rounded, '查询银行账单', '手机号一查，导入待清偿账单', () => go(const BankQueryPage())),
                _item(Icons.mail_outline_rounded, '银行回函', toI(ov['unread_letters']) > 0 ? '${ov['unread_letters']} 封未读' : '受理 · 回执 · 偿清确认', () => go(const LettersPage()), dot: toI(ov['unread_letters']) > 0),
                _item(Icons.workspace_premium_outlined, '偿清证明', '${ov['certificates'] ?? 0} 份', () => go(const CertificatesPage())),
                _item(Icons.trending_up_rounded, '信用分与返还倍率', '信用越好返得越多', () => go(const CreditPage()), last: true),
              ]),
            ),
            SCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                _item(Icons.auto_awesome_rounded, 'AI 助手', '清偿规划 · 任务匹配 · 文案创作', () => go(const AiHubPage())),
                _item(Icons.forum_rounded, '社区', '看看大家的轻松清偿故事', () => go(const CommunityPage2())),
                _item(Icons.play_circle_outline_rounded, '视频指引', '${m.watchedGuides.length}/${m.guides.length} 已看', () => go(const GuideCenterPage()), last: true),
              ]),
            ),
            SCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: EdgeInsets.zero,
              onTap: () => go(const AiHubPage()),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Sx.r),
                child: Row(children: [
                  MallImage(mediaImg('service'), width: 110, height: 86, radius: 0),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('专属顾问 · 7×12 小时', style: Sx.h3),
                    SizedBox(height: 3),
                    Text('不知道先清偿哪一笔？问问我们', style: Sx.small),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: Sx.muted),
                  const SizedBox(width: 10),
                ]),
              ),
            ),
            TextButton(onPressed: m.logout, child: const Text('退出登录', style: TextStyle(color: Sx.muted))),
          ]),
        ),
      ])),
    );
  }

  Widget _num(String k, String v, VoidCallback onTap) => Expanded(child: InkWell(onTap: onTap, child: Column(children: [
        Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Sx.ink)),
        const SizedBox(height: 3),
        Text(k, style: Sx.small),
      ])));

  Widget _ord(BuildContext context, IconData i, String t, int tab) => Expanded(child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MallOrdersPage(initialIndex: tab))),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [Icon(i, color: Sx.ink, size: 24), const SizedBox(height: 6), Text(t, style: const TextStyle(fontSize: 11.5, color: Sx.inkSoft))])),
      ));

  Widget _item(IconData i, String t, String s, VoidCallback onTap, {bool last = false, bool dot = false}) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Sx.line))),
          child: Row(children: [
            Icon(i, color: Sx.ink, size: 21),
            const SizedBox(width: 12),
            Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Sx.ink)),
            if (dot) Container(margin: const EdgeInsets.only(left: 6), width: 7, height: 7, decoration: const BoxDecoration(color: Sx.coral, shape: BoxShape.circle)),
            const Spacer(),
            Flexible(child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: Sx.small)),
            const Icon(Icons.chevron_right_rounded, color: Sx.muted, size: 20),
          ]),
        ),
      );
}
