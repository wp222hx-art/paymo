import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/mall_state.dart';
import '../widgets/common.dart';
import 'account_pages.dart' show AiHubPage, WalletPage;
import 'labor_pages.dart' show laborTypes;
import 'mall_pages.dart' show BankLogo;
import 'mall_widgets.dart';

/// 员工/机构工作台通用框架
class StaffShell extends StatelessWidget {
  final List<(Widget, IconData, String)> tabs;
  const StaffShell(this.tabs, {super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final idx = m.tab.clamp(0, tabs.length - 1);
    return Scaffold(
      backgroundColor: Sx.bg,
      body: IndexedStack(index: idx, children: [for (final t in tabs) t.$1]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: Sx.goldSoft,
        selectedIndex: idx,
        onDestinationSelected: m.setTab,
        height: 62,
        destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$2, color: Sx.inkSoft), selectedIcon: Icon(t.$2, color: Sx.ink), label: t.$3)],
      ),
    );
  }
}

AppBar staffBar(BuildContext context, String title, {List<Widget>? actions}) {
  final m = context.read<MallState>();
  return AppBar(
    backgroundColor: Sx.bg,
    foregroundColor: Sx.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleSpacing: 16,
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Sx.ink, fontSize: 18)),
      Text('${m.me?['org_name'] ?? m.me?['nickname'] ?? ''}', style: Sx.small),
    ]),
    actions: actions,
  );
}

Widget statBox(String k, String v, {Color c = Sx.ink, VoidCallback? onTap}) => Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Sx.shadow(0.04)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
          const SizedBox(height: 3),
          Text(k, style: Sx.small),
        ]),
      ),
    ));

/// 我的（员工版）
class StaffMinePage extends StatelessWidget {
  final String roleName;
  const StaffMinePage(this.roleName, {super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: staffBar(context, '我的'),
      body: ListView(children: [
        SCard(child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: Sx.ink, child: Text('${m.me?['nickname'] ?? ''}'.characters.firstOrNull ?? '?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m.me?['nickname']}', style: Sx.h2),
            const SizedBox(height: 3),
            Text('$roleName · ${m.me?['mobile']}', style: Sx.small),
          ])),
        ])),
        if (m.role == 'merchant')
          SCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
            ListTile(leading: const Icon(Icons.account_balance_wallet_rounded, color: Sx.gold), title: const Text('钱包与押金'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()))),
            ListTile(leading: const Icon(Icons.auto_awesome_rounded, color: Sx.gold), title: const Text('AI 助手（文案 / 任务描述）'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiHubPage()))),
          ])),
        SCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
          ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: const Text('切换演示身份'), onTap: () => showRoleSwitcher(context)),
          ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('退出登录'), onTap: m.logout),
        ])),
      ]),
    );
  }
}

/// 演示身份切换（覆盖所有角色）
const demoAccounts = [
  ('U1001', '林晓明', '用户 · 3 笔账单待导入'),
  ('U1002', '苏雨桐', '用户 · 已有一笔偿清 · 已绑卡'),
  ('M2001', '星辰品牌', '商家 · 发布任务 / 验收'),
  ('M2002', '云栖餐饮集团', '商家'),
  ('B3002', '马上消费金融 · 李清', '合作银行专员'),
  ('B3001', '招商银行 · 顾承业', '合作银行专员'),
  ('R4001', '风控 · 陈锐', '风控 / 运营专员'),
];

Future<void> showRoleSwitcher(BuildContext context) => showXSheet(context, title: '切换演示身份', Builder(builder: (ctx) {
      final m = ctx.read<MallState>();
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
        for (final a in demoAccounts)
          ListTile(
            leading: CircleAvatar(backgroundColor: a.$1 == m.extId ? Sx.ink : Sx.bg, child: Text(a.$2.characters.first, style: TextStyle(color: a.$1 == m.extId ? Colors.white : Sx.ink, fontWeight: FontWeight.w800))),
            title: Text(a.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(a.$3),
            trailing: a.$1 == m.extId ? const Icon(Icons.check_circle_rounded, color: Sx.mint) : null,
            onTap: () {
              Navigator.pop(ctx);
              m.loginAs(a.$1);
            },
          ),
      ]);
    }));

// ───────────────────────── 商家工作台 ─────────────────────────

class MerchantShell extends StatelessWidget {
  const MerchantShell({super.key});
  @override
  Widget build(BuildContext context) => const StaffShell([
        (MerchantHome(), Icons.dashboard_rounded, '工作台'),
        (MerchantTasksPage(), Icons.assignment_rounded, '我的任务'),
        (MerchantReviewPage(), Icons.fact_check_rounded, '验收'),
        (StaffMinePage('商家'), Icons.person_rounded, '我的'),
      ]);
}

class MerchantHome extends StatelessWidget {
  const MerchantHome({super.key});
  @override
  Widget build(BuildContext context) {
    context.watch<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: staffBar(context, '商家工作台'),
      body: MallGate(builder: (ctx, m) => Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await m.get('/merchant/overview')),
        builder: (ctx, o, reload) {
          final t = (o['tasks'] as Map?) ?? const {};
          return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: ClipRRect(borderRadius: BorderRadius.circular(Sx.r), child: SizedBox(height: 150, child: Stack(fit: StackFit.expand, children: [
                MallImage(mediaImg('merchant_hero'), radius: 0, full: true),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xEE121A33), Color(0x22121A33)]))),
                Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('把零散的工作，交给真实的人', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('押金平台托管 · AI 初审 · 验收后才结算', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  SizedBox(width: 150, child: SButton('发布任务', gold: true, icon: Icons.add_rounded, onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishTaskPage())); reload(); })),
                ])),
              ]))),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
              statBox('可用余额', fmtMoney(toD(o['wallet']))),
              const SizedBox(width: 10),
              statBox('托管押金', fmtMoney(toD(o['frozen'])), c: Sx.gold),
            ])),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
              statBox('待验收', '${o['to_review']}', c: Sx.coral, onTap: () => m.setTab(2)),
              const SizedBox(width: 10),
              statBox('进行中任务', '${t['live'] ?? 0}', onTap: () => m.setTab(1)),
              const SizedBox(width: 10),
              statBox('已完成份数', '${t['done'] ?? 0}', c: Sx.mint),
            ])),
            const SHeader('怎么做'),
            for (final (i, s) in const [
              ('发布任务', '写清要求、设置报酬与名额，押金由平台托管'),
              ('用户接单交付', 'AI 先做原创与合规初审，过滤敷衍与搬运'),
              ('你来验收', '72 小时内验收，通过即结算；驳回需写明原因'),
              ('自动结算', '报酬按比例变成用户的现金与清偿金，剩余押金退回'),
            ].indexed)
              SCard(padding: const EdgeInsets.all(14), child: Row(children: [
                CircleAvatar(radius: 14, backgroundColor: Sx.goldSoft, child: Text('${i + 1}', style: const TextStyle(color: Sx.gold, fontWeight: FontWeight.w900))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.$1, style: Sx.h3), Text(s.$2, style: Sx.small)])),
              ])),
            Padding(padding: const EdgeInsets.all(16), child: SButton('充值（模拟）', primary: false, icon: Icons.add_card_rounded, onTap: () async { await mallRun(context, () => m.post('/merchant/recharge', {'amount': 10000}), success: '已充值 ¥10,000'); reload(); })),
          ]);
        },
      )),
    );
  }
}

class MerchantTasksPage extends StatefulWidget {
  const MerchantTasksPage({super.key});
  @override
  State<MerchantTasksPage> createState() => _MerchantTasksPageState();
}

class _MerchantTasksPageState extends State<MerchantTasksPage> {
  final _k = GlobalKey<LoaderState<List<dynamic>>>();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: staffBar(context, '我的任务', actions: [IconButton(icon: const Icon(Icons.add_circle_rounded, color: Sx.ink), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishTaskPage())); _k.currentState?.reload(); })]),
      body: Loader<List<dynamic>>(
        key: _k,
        load: () async => await m.get('/merchant/tasks') as List<dynamic>,
        builder: (ctx, list, reload) => list.isEmpty
            ? ListView(children: const [SEmpty('还没有发布任务')])
            : ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
                for (final t in list)
                  SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon((laborTypes[t['task_type']] ?? laborTypes['content']!).$2, color: (laborTypes[t['task_type']] ?? laborTypes['content']!).$3, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${t['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Sx.h3)),
                      SPill('${t['status_label']}', color: switch (toI(t['status'])) { 2 => Sx.mint, 1 => Sx.gold, 8 => Sx.coral, _ => Sx.muted }),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 6, value: toI(t['quota']) == 0 ? 0 : toI(t['done']) / toI(t['quota']), color: Sx.mint, backgroundColor: Sx.line)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('${fmtMoney(toD(t['reward']))}/份 · 已完成 ${t['done']}/${t['quota']} · 报名 ${t['taken']}', style: Sx.small),
                      const Spacer(),
                      Text('押金余 ${fmtMoney(toD(t['deposit_left']))}', style: Sx.small),
                    ]),
                    if (t['reject_reason'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('驳回原因：${t['reject_reason']}', style: const TextStyle(fontSize: 12, color: Sx.coral))),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (toI(t['pending']) > 0) TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MerchantReviewPage(taskId: toI(t['id']), title: '${t['title']}'))).then((_) => reload()), child: Text('${t['pending']} 份待验收', style: const TextStyle(color: Sx.coral, fontWeight: FontWeight.w800))),
                      if ([1, 2, 3].contains(toI(t['status']))) TextButton(onPressed: () async { await mallRun(context, () => m.post('/merchant/tasks/${t['id']}/close'), success: '已下架，剩余押金已退回'); reload(); }, child: const Text('下架', style: TextStyle(color: Sx.muted))),
                    ]),
                  ])),
              ]),
      ),
    );
  }
}

class MerchantReviewPage extends StatefulWidget {
  final int? taskId;
  final String? title;
  const MerchantReviewPage({super.key, this.taskId, this.title});
  @override
  State<MerchantReviewPage> createState() => _MerchantReviewPageState();
}

class _MerchantReviewPageState extends State<MerchantReviewPage> {
  final _k = GlobalKey<LoaderState<List<dynamic>>>();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: widget.taskId == null ? staffBar(context, '待验收') : AppBar(backgroundColor: Sx.bg, foregroundColor: Sx.ink, title: Text(widget.title ?? '验收', style: const TextStyle(color: Sx.ink, fontWeight: FontWeight.w800))),
      body: Loader<List<dynamic>>(
        key: _k,
        load: () async => await m.get('/merchant/orders?status=50${widget.taskId != null ? '&task_id=${widget.taskId}' : ''}') as List<dynamic>,
        builder: (ctx, list, reload) => list.isEmpty
            ? ListView(children: const [SEmpty('暂时没有待验收的交付', img: 'empty_debt')])
            : ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
                for (final o in list)
                  SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${(o['task'] as Map)['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Sx.h3)),
                      SPill('AI ${toD(o['ai_score']).toStringAsFixed(0)} 分', color: toD(o['ai_score']) >= 80 ? Sx.mint : Sx.gold, icon: Icons.auto_awesome_rounded),
                    ]),
                    const SizedBox(height: 4),
                    Text('${(o['worker'] as Map?)?['nickname'] ?? ''} · 提交于 ${o['submitted_at'] != null ? fmtDate(DateTime.parse(o['submitted_at'] as String).toLocal()) : ''} · ${o['review_due_at'] != null ? '${fmtDate(DateTime.parse(o['review_due_at'] as String).toLocal())} 前未处理将自动通过' : ''}', style: Sx.small),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Sx.bg, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${o['submission_text'] ?? ''}', style: Sx.body),
                        if (o['submission_link'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${o['submission_link']}', style: const TextStyle(color: Sx.blue, fontSize: 12))),
                        if ((o['submission_files'] as List).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, children: [for (final f in o['submission_files'] as List) MallImage(f as String, width: 60, height: 60, radius: 8, full: true)])),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: SButton('驳回', primary: false, onTap: () => _review(m, o, false))),
                      const SizedBox(width: 10),
                      Expanded(child: SButton('通过并结算', onTap: () => _review(m, o, true))),
                    ]),
                  ])),
              ]),
      ),
    );
  }

  Future<void> _review(MallState m, Map o, bool approve) async {
    String? note;
    int rating = 5;
    if (!approve) {
      final c = TextEditingController();
      note = await showDialog<String>(context: context, builder: (dc) => AlertDialog(
        title: const Text('驳回原因'),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: '具体说明哪里不符合要求（用户可申诉）')),
        actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dc, c.text), child: const Text('驳回'))],
      ));
      if (note == null) return;
    } else {
      final ok = await showDialog<int>(context: context, builder: (dc) => StatefulBuilder(builder: (dc, setSt) => AlertDialog(
        title: const Text('通过并结算'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('将从押金中结算 ${fmtMoney(toD((o['task'] as Map)['reward']))} 给用户'),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 1; i <= 5; i++) IconButton(onPressed: () => setSt(() => rating = i), icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_border_rounded, color: Sx.gold))]),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dc, rating), child: const Text('确认'))],
      )));
      if (ok == null) return;
      rating = ok;
    }
    if (!mounted) return;
    await mallRun(context, () => m.post('/merchant/orders/${o['id']}/review', {'approve': approve, 'note': note, 'rating': rating}), success: approve ? '已通过，报酬已结算给用户' : '已驳回');
    _k.currentState?.reload();
  }
}

class PublishTaskPage extends StatefulWidget {
  const PublishTaskPage({super.key});
  @override
  State<PublishTaskPage> createState() => _PublishTaskPageState();
}

class _PublishTaskPageState extends State<PublishTaskPage> {
  String _type = 'content';
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _req = TextEditingController();
  final _city = TextEditingController();
  double _reward = 100;
  int _quota = 10;
  double _cash = 40;
  int _kyc = 2;
  int _hours = 72;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    final net = _reward * 0.9;
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: AppBar(backgroundColor: Sx.bg, foregroundColor: Sx.ink, title: const Text('发布任务', style: TextStyle(color: Sx.ink, fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('任务类型', style: Sx.h3),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in laborTypes.entries) ChoiceChip(avatar: Icon(e.value.$2, size: 16, color: _type == e.key ? Colors.white : e.value.$3), label: Text(e.value.$1), selected: _type == e.key, selectedColor: Sx.ink, labelStyle: TextStyle(color: _type == e.key ? Colors.white : Sx.ink), onSelected: (_) => setState(() => _type = e.key)),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _title, maxLength: 60, decoration: const InputDecoration(labelText: '标题', hintText: '如：新品面霜 小红书图文笔记')),
          TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(labelText: '任务说明', hintText: '写清楚要做什么、怎么做')),
          TextField(controller: _req, maxLines: 3, decoration: const InputDecoration(labelText: '交付要求（每行一条）', hintText: '正文 ≥ 300 字\n实拍图 ≥ 3 张')),
          TextField(controller: _city, decoration: const InputDecoration(labelText: '城市（线下任务填写，线上留空）')),
        ])),
        SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Text('单份报酬', style: Sx.h3), const Spacer(), PriceText(_reward, size: 20)]),
          Slider(value: _reward, min: 5, max: 1000, divisions: 199, activeColor: Sx.ink, onChanged: (v) => setState(() => _reward = v.roundToDouble())),
          Row(children: [const Text('名额', style: Sx.h3), const Spacer(), Text('$_quota 份', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
          Slider(value: _quota.toDouble(), min: 1, max: 500, divisions: 499, activeColor: Sx.ink, onChanged: (v) => setState(() => _quota = v.round())),
          Row(children: [const Text('报酬中现金占比', style: Sx.h3), const Spacer(), Text('现金 ${_cash.round()}% · 清偿金 ${100 - _cash.round()}%', style: const TextStyle(fontWeight: FontWeight.w800))]),
          Slider(value: _cash, min: 0, max: 100, divisions: 20, activeColor: Sx.gold, onChanged: (v) => setState(() => _cash = v)),
          Text('用户每份实得：现金 ${fmtMoney(net * _cash / 100)} + 清偿金 ${fmtMoney(net * (100 - _cash) / 100)} 起（信用好的用户清偿金还有加成）', style: Sx.small),
        ])),
        SCard(child: Column(children: [
          Row(children: [
            const Text('接单门槛', style: Sx.h3),
            const Spacer(),
            DropdownButton<int>(value: _kyc, underline: const SizedBox(), items: const [DropdownMenuItem(value: 1, child: Text('手机认证')), DropdownMenuItem(value: 2, child: Text('实名认证')), DropdownMenuItem(value: 3, child: Text('活体认证')), DropdownMenuItem(value: 4, child: Text('银行卡认证'))], onChanged: (v) => setState(() => _kyc = v!)),
          ]),
          Row(children: [
            const Text('交付时限', style: Sx.h3),
            const Spacer(),
            DropdownButton<int>(value: _hours, underline: const SizedBox(), items: const [DropdownMenuItem(value: 4, child: Text('4 小时')), DropdownMenuItem(value: 24, child: Text('1 天')), DropdownMenuItem(value: 72, child: Text('3 天')), DropdownMenuItem(value: 168, child: Text('7 天'))], onChanged: (v) => setState(() => _hours = v!)),
          ]),
        ])),
        SCard(
          color: Sx.goldSoft,
          child: Row(children: [
            const Icon(Icons.lock_rounded, color: Sx.gold),
            const SizedBox(width: 10),
            Expanded(child: Text('需托管押金 ${fmtMoney(_reward * _quota)}，按完成份数结算，未用完部分自动退回。平台服务费 10%（从报酬中扣除）。', style: Sx.body)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: SButton('托管押金并发布', loading: _busy, onTap: () async {
          setState(() => _busy = true);
          final r = await mallRun(context, () async => Map<String, dynamic>.from(await m.post('/merchant/tasks', {
                'task_type': _type, 'title': _title.text.trim(), 'description': _desc.text.trim(), 'requirements': _req.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                'reward': _reward, 'quota': _quota, 'cash_pct': _cash.round(), 'clear_pct': 100 - _cash.round(), 'kyc_required': _kyc, 'duration_hours': _hours, 'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
              })));
          if (!mounted) return;
          setState(() => _busy = false);
          if (r == null || !context.mounted) return;
          mallToast(context, toI(r['status']) == 2 ? '已发布，开始招募' : '已提交，平台审核后上架');
          Navigator.pop(context);
        })),
      ]),
    );
  }
}

// ───────────────────────── 银行专员工作台 ─────────────────────────

class BankShell extends StatelessWidget {
  const BankShell({super.key});
  @override
  Widget build(BuildContext context) => const StaffShell([
        (BankDeskHome(), Icons.dashboard_rounded, '概览'),
        (BankQueuePage(), Icons.inbox_rounded, '清偿受理'),
        (BankCasesPage(), Icons.folder_shared_rounded, '本行账单'),
        (StaffMinePage('合作银行专员'), Icons.person_rounded, '我的'),
      ]);
}

class BankDeskHome extends StatelessWidget {
  const BankDeskHome({super.key});
  @override
  Widget build(BuildContext context) {
    context.watch<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: staffBar(context, '银行工作台'),
      body: MallGate(builder: (ctx, m) => Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await m.get('/bank-desk/overview')),
        builder: (ctx, o, _) {
          final c = (o['cases'] as Map?) ?? const {};
          final q = (o['queue'] as Map?) ?? const {};
          return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            SCard(gradient: Sx.heroGrad, child: Row(children: [
              BankLogo(o['bank'] as Map?, size: 48),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${(o['bank'] as Map?)?['name'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const Text('星光云清偿通道 · 只显示本行数据', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ])),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
              statBox('待处理清偿', '${q['n'] ?? 0}', c: Sx.coral, onTap: () => m.setTab(1)),
              const SizedBox(width: 10),
              statBox('待处理金额', fmtMoney(toD(q['amt']))),
            ])),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
              statBox('已收资金', fmtMoney(toD(o['received'])), c: Sx.mint),
              const SizedBox(width: 10),
              statBox('接入账单', '${c['n'] ?? 0} 笔', onTap: () => m.setTab(2)),
              const SizedBox(width: 10),
              statBox('已出具证明', '${o['certificates']}', c: Sx.gold),
            ])),
            SCard(margin: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('本行账单清偿进度', style: Sx.h3),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(minHeight: 8, value: toD(c['principal']) == 0 ? 0 : toD(c['cleared']) / toD(c['principal']), color: Sx.mint, backgroundColor: Sx.line)),
              const SizedBox(height: 8),
              Text('已清偿 ${fmtMoney(toD(c['cleared']))} / 接入总额 ${fmtMoney(toD(c['principal']))} · 已偿清 ${c['settled'] ?? 0} 笔', style: Sx.small),
            ])),
            const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 0), child: Text('流程：用户提交 → 你受理 → 平台从备付金划转资金 → 你核减账单（余额归零自动出具偿清证明）。受理阶段可退回。', style: Sx.small)),
          ]);
        },
      )),
    );
  }
}

class BankQueuePage extends StatefulWidget {
  const BankQueuePage({super.key});
  @override
  State<BankQueuePage> createState() => _BankQueuePageState();
}

class _BankQueuePageState extends State<BankQueuePage> {
  final _k = GlobalKey<LoaderState<List<dynamic>>>();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: staffBar(context, '清偿受理'),
      body: Loader<List<dynamic>>(
        key: _k,
        load: () async => await m.get('/bank-desk/clearances') as List<dynamic>,
        builder: (ctx, list, reload) => list.isEmpty
            ? ListView(children: const [SEmpty('队列已清空', img: 'empty_debt')])
            : ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
                for (final c in list)
                  SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${c['nickname']} · ${c['case_no']}', style: Sx.h3)),
                      SPill('${c['status_label']}', color: toI(c['status']) == 30 ? Sx.blue : Sx.gold),
                    ]),
                    const SizedBox(height: 6),
                    Text('清偿 ${fmtMoney(toD(c['points']))}（资金 ${fmtMoney(toD(c['cash_remitted']))} + 银行让利 ${fmtMoney(toD(c['reduction']))}）· 账单剩余 ${fmtMoney(toD(c['outstanding']))}', style: Sx.small),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if ([10, 20].contains(toI(c['status']))) TextButton(onPressed: () => _act(m, c, 'reject'), child: const Text('退回', style: TextStyle(color: Sx.coral))),
                      if (toI(c['status']) == 10) SizedBox(width: 110, child: SButton('受理', onTap: () => _act(m, c, 'accept'))),
                      if (toI(c['status']) == 20) const Text('等待平台划转资金…', style: Sx.small),
                      if (toI(c['status']) == 30) SizedBox(width: 130, child: SButton('核减账单', onTap: () => _act(m, c, 'write-off'))),
                    ]),
                  ])),
              ]),
      ),
    );
  }

  Future<void> _act(MallState m, Map c, String a) async {
    String? reason;
    if (a == 'reject') {
      final t = TextEditingController(text: '账户信息不一致');
      reason = await showDialog<String>(context: context, builder: (dc) => AlertDialog(title: const Text('退回原因'), content: TextField(controller: t), actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dc, t.text), child: const Text('退回'))]));
      if (reason == null) return;
    }
    if (!mounted) return;
    await mallRun(context, () => m.post('/bank-desk/clearances/${c['id']}/$a', {'reason': reason}), success: {'accept': '已受理', 'write-off': '已核减', 'reject': '已退回'}[a]);
    _k.currentState?.reload();
  }
}

class BankCasesPage extends StatelessWidget {
  const BankCasesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: staffBar(context, '本行账单'),
      body: Loader<List<dynamic>>(
        load: () async => await m.get('/bank-desk/cases') as List<dynamic>,
        builder: (ctx, list, _) => list.isEmpty
            ? ListView(children: const [SEmpty('还没有用户接入本行账单', img: 'empty_debt')])
            : ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
                for (final d in list)
                  SCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${d['nickname']} · ${d['debt_type']} · ${d['case_no']}', style: Sx.h3)),
                      if (toI(d['status']) == 3) const SPill('已偿清', color: Sx.mint),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 5, value: toD(d['principal']) == 0 ? 0 : toD(d['cleared']) / toD(d['principal']), color: Sx.mint, backgroundColor: Sx.line)),
                    const SizedBox(height: 6),
                    Text('剩余 ${fmtMoney(toD(d['outstanding']))} / ${fmtMoney(toD(d['principal']))}', style: Sx.small),
                  ])),
              ]),
      ),
    );
  }
}

// ───────────────────────── 风控 / 运营工作台 ─────────────────────────

class RiskShell extends StatelessWidget {
  const RiskShell({super.key});
  @override
  Widget build(BuildContext context) => const StaffShell([
        (RiskHome(), Icons.shield_rounded, '风控'),
        (RiskQueuePage(), Icons.fact_check_rounded, '待处理'),
        (StaffMinePage('风控 / 运营专员'), Icons.person_rounded, '我的'),
      ]);
}

class RiskHome extends StatelessWidget {
  const RiskHome({super.key});
  @override
  Widget build(BuildContext context) {
    context.watch<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: staffBar(context, '风控与运营'),
      body: MallGate(builder: (ctx, m) => Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await m.get('/risk-desk/overview')),
        builder: (ctx, o, _) => ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Row(children: [
            statBox('风险案件', '${o['open_cases']}', c: Sx.coral, onTap: () => m.setTab(1)),
            const SizedBox(width: 10),
            statBox('提现待审', '${(o['withdraw_review'] as Map)['n']}', c: Sx.gold, onTap: () => m.setTab(1)),
          ])),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
            statBox('任务申诉', '${o['disputes']}', onTap: () => m.setTab(1)),
            const SizedBox(width: 10),
            statBox('内容待审', '${o['posts_review']}', onTap: () => m.setTab(1)),
            const SizedBox(width: 10),
            statBox('任务待审', '${o['task_audit']}'),
          ])),
          const SHeader('风控规则', sub: '规则阈值在运营后台调整'),
          for (final r in (o['rules'] as List))
            SCard(padding: const EdgeInsets.all(14), child: Row(children: [
              Icon(r['enabled'] == 1 ? Icons.toggle_on_rounded : Icons.toggle_off_rounded, color: r['enabled'] == 1 ? Sx.mint : Sx.muted, size: 30),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['name']}', style: Sx.h3),
                Text('${r['code']} · ${r['description']}', style: Sx.small),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                SPill({'block': '拦截', 'review': '人工复核', 'pass': '放行'}[r['action']] ?? '${r['action']}', color: r['action'] == 'block' ? Sx.coral : Sx.gold),
                const SizedBox(height: 4),
                Text('命中 ${r['hits']}', style: Sx.small),
              ]),
            ])),
        ]),
      )),
    );
  }
}

class RiskQueuePage extends StatefulWidget {
  const RiskQueuePage({super.key});
  @override
  State<RiskQueuePage> createState() => _RiskQueuePageState();
}

class _RiskQueuePageState extends State<RiskQueuePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Sx.bg,
        appBar: AppBar(
          backgroundColor: Sx.bg,
          foregroundColor: Sx.ink,
          title: const Text('待处理', style: TextStyle(color: Sx.ink, fontWeight: FontWeight.w900)),
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelColor: Sx.ink, unselectedLabelColor: Sx.muted, indicatorColor: Sx.gold, dividerColor: Colors.transparent, tabs: [Tab(text: '风险案件'), Tab(text: '提现审核'), Tab(text: '任务申诉'), Tab(text: '内容审核')]),
        ),
        body: const TabBarView(children: [_RiskCases(), _Withdrawals(), _Disputes(), _Posts()]),
      ),
    );
  }
}

class _RiskCases extends StatelessWidget {
  const _RiskCases();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Loader<List<dynamic>>(
      load: () async => await m.get('/risk-desk/cases') as List<dynamic>,
      builder: (ctx, list, reload) => list.isEmpty
          ? ListView(children: const [SEmpty('没有待处置的风险案件', img: 'empty_debt')])
          : ListView(padding: const EdgeInsets.only(top: 8, bottom: 30), children: [
              for (final c in list)
                SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${c['rule_name']}', style: Sx.h3)),
                    SPill('${c['score']} 分', color: toI(c['score']) >= 80 ? Sx.coral : Sx.gold),
                  ]),
                  const SizedBox(height: 4),
                  Text('${c['nickname'] ?? 'U${c['user_id']}'} · ${c['scene']} · ${c['detail']}', style: Sx.small),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => _h(context, m, c, 'freeze', reload), child: const Text('冻结账号', style: TextStyle(color: Sx.coral))),
                    TextButton(onPressed: () => _h(context, m, c, 'block', reload), child: const Text('拦截')),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Sx.ink), onPressed: () => _h(context, m, c, 'pass', reload), child: const Text('放行')),
                  ]),
                ])),
            ]),
    );
  }

  Future<void> _h(BuildContext context, MallState m, Map c, String a, VoidCallback reload) async {
    await mallRun(context, () => m.post('/risk-desk/cases/${c['id']}', {'action': a, 'note': a == 'pass' ? '核实无误' : '风控处置'}), success: '已处理');
    reload();
  }
}

class _Withdrawals extends StatelessWidget {
  const _Withdrawals();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Loader<List<dynamic>>(
      load: () async => await m.get('/risk-desk/withdrawals') as List<dynamic>,
      builder: (ctx, list, reload) => list.isEmpty
          ? ListView(children: const [SEmpty('没有待审核的提现', img: 'empty_debt')])
          : ListView(padding: const EdgeInsets.only(top: 8, bottom: 30), children: [
              for (final w in list)
                SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('${w['nickname']} 提现 ${fmtMoney(toD(w['amount']))}', style: Sx.h3)), SPill('风险 ${toI(w['risk_score'])}', color: Sx.gold)]),
                  const SizedBox(height: 4),
                  Text('${w['bank_name']} ${w['card_mask']} · ${(w['risk_hits'] as List).map((h) => h['name']).join('、')}', style: Sx.small),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () async { await mallRun(ctx, () => m.post('/risk-desk/withdrawals/${w['id']}', {'action': 'reject', 'note': '风控核实未通过'}), success: '已驳回，资金退回用户钱包'); reload(); }, child: const Text('驳回', style: TextStyle(color: Sx.coral))),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Sx.ink), onPressed: () async { await mallRun(ctx, () => m.post('/risk-desk/withdrawals/${w['id']}', {'action': 'approve'}), success: '已放款'); reload(); }, child: const Text('通过放款')),
                  ]),
                ])),
            ]),
    );
  }
}

class _Disputes extends StatelessWidget {
  const _Disputes();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Loader<List<dynamic>>(
      load: () async => await m.get('/risk-desk/disputes') as List<dynamic>,
      builder: (ctx, list, reload) => list.isEmpty
          ? ListView(children: const [SEmpty('没有待仲裁的申诉', img: 'empty_debt')])
          : ListView(padding: const EdgeInsets.only(top: 8, bottom: 30), children: [
              for (final o in list)
                SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${(o['task'] as Map)['title']}', style: Sx.h3),
                  const SizedBox(height: 4),
                  Text('${(o['worker'] as Map?)?['nickname']} · AI ${toD(o['ai_score']).toStringAsFixed(0)} 分', style: Sx.small),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Sx.bg, borderRadius: BorderRadius.circular(10)), child: Text('交付：${o['submission_text'] ?? ''}\n商家驳回：${o['review_note'] ?? ''}\n用户申诉：${o['dispute_reason'] ?? ''}', style: Sx.body)),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () async { await mallRun(ctx, () => m.post('/risk-desk/disputes/${o['id']}', {'approve': false, 'note': '交付确不符合要求'}), success: '已维持驳回'); reload(); }, child: const Text('维持驳回')),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Sx.ink), onPressed: () async { await mallRun(ctx, () => m.post('/risk-desk/disputes/${o['id']}', {'approve': true, 'note': '交付符合要求'}), success: '已支持用户并结算'); reload(); }, child: const Text('支持用户')),
                  ]),
                ])),
            ]),
    );
  }
}

class _Posts extends StatelessWidget {
  const _Posts();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Loader<List<dynamic>>(
      load: () async => await m.get('/risk-desk/posts') as List<dynamic>,
      builder: (ctx, list, reload) => list.isEmpty
          ? ListView(children: const [SEmpty('没有待审核的内容', img: 'empty_debt')])
          : ListView(padding: const EdgeInsets.only(top: 8, bottom: 30), children: [
              for (final p in list)
                SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['title']}', style: Sx.h3),
                  const SizedBox(height: 4),
                  Text('${p['body']}', maxLines: 4, overflow: TextOverflow.ellipsis, style: Sx.body),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () async { await mallRun(ctx, () => m.post('/risk-desk/posts/${p['id']}', {'action': 'block', 'note': '违反社区规范'}), success: '已拦截'); reload(); }, child: const Text('拦截', style: TextStyle(color: Sx.coral))),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Sx.ink), onPressed: () async { await mallRun(ctx, () => m.post('/risk-desk/posts/${p['id']}', {'action': 'approve'}), success: '已发布'); reload(); }, child: const Text('发布')),
                  ]),
                ])),
            ]),
    );
  }
}


