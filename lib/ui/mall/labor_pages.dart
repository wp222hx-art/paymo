import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/mall_state.dart';
import '../widgets/common.dart';
import 'account_pages.dart' show KycPage, WalletPage;
import 'mall_order_pages.dart' show sAppBar;
import 'mall_widgets.dart';

const laborTypes = {
  'content': ('内容种草', Icons.videocam_rounded, Color(0xFFE86A4F)),
  'survey': ('问卷调研', Icons.fact_check_rounded, Color(0xFF3D6AF2)),
  'visit': ('门店探访', Icons.storefront_rounded, Color(0xFFC9A063)),
  'service': ('线上客服', Icons.headset_mic_rounded, Color(0xFF7C5CE0)),
  'promo': ('社群推广', Icons.campaign_rounded, Color(0xFFE0559A)),
  'skill': ('技能服务', Icons.design_services_rounded, Color(0xFF2B8DBF)),
  'label': ('数据标注', Icons.label_rounded, Color(0xFF2FA37A)),
  'errand': ('同城跑腿', Icons.delivery_dining_rounded, Color(0xFFF08C2B)),
};

Color orderStatusColor(int s) => switch (s) {
      20 || 10 => Sx.blue,
      40 || 50 => Sx.gold,
      45 || 55 => Sx.coral,
      60 || 80 => Sx.mint,
      _ => Sx.muted,
    };

/// 报酬拆分条：现金 / 清偿金
class SplitBar extends StatelessWidget {
  final Map t;
  final bool compact;
  const SplitBar(this.t, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final cash = toD(t['est_cash']);
    final clear = toD(t['est_clear'] ?? t['est_clear_cash']);
    final m = toD(t['est_multiplier']);
    if (compact) {
      return Row(children: [
        SPill('现金 ${fmtMoney(cash)}', color: Sx.gold, icon: Icons.account_balance_wallet_rounded),
        const SizedBox(width: 6),
        SPill('清偿金 ${fmtMoney(clear)}', color: Sx.mint, icon: Icons.eco_rounded),
      ]);
    }
    final tot = cash + clear;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(height: 10, child: Row(children: [
          Expanded(flex: (cash / (tot == 0 ? 1 : tot) * 100).round().clamp(1, 99), child: Container(color: Sx.gold)),
          Expanded(flex: (clear / (tot == 0 ? 1 : tot) * 100).round().clamp(1, 99), child: Container(color: Sx.mint)),
        ])),
      ),
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.circle, size: 9, color: Sx.gold),
        const SizedBox(width: 4),
        Text('可提现现金 ${fmtMoney(cash)}', style: const TextStyle(fontSize: 12, color: Sx.ink, fontWeight: FontWeight.w700)),
        const Spacer(),
        const Icon(Icons.circle, size: 9, color: Sx.mint),
        const SizedBox(width: 4),
        Text('清偿金 ${fmtMoney(clear)}${m > 1 ? '（含信用加成 ×$m）' : ''}', style: const TextStyle(fontSize: 12, color: Sx.ink, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }
}

// ───────────────────────── 微劳动广场 ─────────────────────────

class LaborHomePage extends StatefulWidget {
  final bool embedded;
  const LaborHomePage({super.key, this.embedded = false});
  @override
  State<LaborHomePage> createState() => _LaborHomePageState();
}

class _LaborHomePageState extends State<LaborHomePage> {
  String? _type;
  String _sort = '';
  bool _remote = false;
  Future<List<dynamic>>? _f;
  MallState? _bound;

  void _load(MallState m) {
    final q = <String, String>{if (_type != null) 'type': _type!, if (_sort.isNotEmpty) 'sort': _sort, if (_remote) 'remote': '1'};
    _f = m.get('/labor/tasks?${Uri(queryParameters: q).query}').then((v) => v as List<dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    if (m.ready && m.me != null && _bound != m) {
      _bound = m;
      _load(m);
    }
    final s = m.laborSummary ?? const {};
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Sx.bg,
      body: MallGate(builder: (ctx, m) => RefreshIndicator(
        color: Sx.gold,
        onRefresh: () async {
          await m.refreshMe();
          setState(() => _load(m));
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Stack(children: [
            SizedBox(height: 236 + top, width: double.infinity, child: Stack(fit: StackFit.expand, children: [
              MallImage(mediaImg('labor_hero'), radius: 0, full: true, alignment: const Alignment(0.4, -0.2)),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA121A33), Color(0x22121A33), Color(0xEE121A33)], stops: [0, 0.4, 1]))),
            ])),
            Padding(
              padding: EdgeInsets.fromLTRB(20, top + 14, 12, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (!widget.embedded) IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  const Text('微劳动', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const Spacer(),
                  TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTasksPage())), icon: const Icon(Icons.assignment_rounded, color: Colors.white, size: 18), label: Text('我的任务${toI(s['active']) > 0 ? ' · ${s['active']}' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 18),
                const Text('碎片时间，\n也能帮你轻松清偿。', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.3)),
                const SizedBox(height: 6),
                const Text('拍视频、填问卷、探门店 · 报酬一份现金一份清偿金', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ])),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: SCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTasksPage())),
              child: Row(children: [
                _num('累计现金', fmtMoney(toD(s['cash'])), Sx.gold),
                _num('累计清偿金', fmtMoney(toD(s['clear'])), Sx.mint),
                _num('已完成', '${s['done'] ?? 0} 单', Sx.ink),
                _num('等级', 'Lv.${s['level'] ?? 1}', Sx.ink),
              ]),
            ),
          )),
          if (toI(s['kyc']) < 2)
            SliverToBoxAdapter(child: SCard(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              color: Sx.blueSoft,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycPage())),
              child: const Row(children: [
                Icon(Icons.verified_user_rounded, color: Sx.blue),
                SizedBox(width: 10),
                Expanded(child: Text('完成实名认证，解锁 90% 的任务', style: Sx.h3)),
                Icon(Icons.chevron_right_rounded, color: Sx.muted),
              ]),
            )),
          SliverToBoxAdapter(child: Row(children: [
            Expanded(child: GuideStrip('task', margin: const EdgeInsets.fromLTRB(16, 0, 6, 0))),
          ])),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              childAspectRatio: 0.95,
              children: [
                for (final e in laborTypes.entries)
                  GestureDetector(
                    onTap: () => setState(() {
                      _type = _type == e.key ? null : e.key;
                      _load(m);
                    }),
                    child: Container(
                      decoration: BoxDecoration(color: _type == e.key ? e.value.$3 : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Sx.shadow(0.03)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(e.value.$2, color: _type == e.key ? Colors.white : e.value.$3, size: 24),
                        const SizedBox(height: 6),
                        Text(e.value.$1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _type == e.key ? Colors.white : Sx.ink)),
                      ]),
                    ),
                  ),
              ],
            ),
          )),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Text(_type == null ? '全部任务' : laborTypes[_type]!.$1, style: Sx.h2),
              const Spacer(),
              for (final s in const [('', '推荐'), ('reward', '报酬高'), ('quick', '耗时短'), ('clear', '清偿多')])
                Padding(padding: const EdgeInsets.only(left: 12), child: GestureDetector(
                  onTap: () => setState(() {
                    _sort = s.$1;
                    _load(m);
                  }),
                  child: Text(s.$2, style: TextStyle(fontSize: 12.5, fontWeight: _sort == s.$1 ? FontWeight.w800 : FontWeight.w500, color: _sort == s.$1 ? Sx.ink : Sx.muted)),
                )),
            ]),
          )),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 4),
            child: Row(children: [
              Checkbox(value: _remote, activeColor: Sx.ink, visualDensity: VisualDensity.compact, onChanged: (v) => setState(() {
                _remote = v ?? false;
                _load(m);
              })),
              const Text('只看在家可做', style: Sx.small),
            ]),
          )),
          FutureBuilder<List<dynamic>>(
            future: _f,
            builder: (ctx, snap) {
              if (!snap.hasData) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: Sx.gold))));
              final list = snap.data!;
              if (list.isEmpty) return const SliverToBoxAdapter(child: SEmpty('这个分类暂时没有任务，换一个看看'));
              return SliverList(delegate: SliverChildBuilderDelegate((_, i) => TaskCard(list[i] as Map, onBack: () => setState(() => _load(m))), childCount: list.length));
            },
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              Expanded(child: GuideStrip('submit', margin: EdgeInsets.zero)),
            ]),
          )),
          const SliverToBoxAdapter(child: GuideStrip('income', margin: EdgeInsets.fromLTRB(16, 10, 16, 28))),
        ]),
      )),
    );
  }

  Widget _num(String k, String v, Color c) => Expanded(child: Column(children: [
        Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c)),
        const SizedBox(height: 3),
        Text(k, style: Sx.small),
      ]));
}

class TaskCard extends StatelessWidget {
  final Map t;
  final VoidCallback? onBack;
  const TaskCard(this.t, {super.key, this.onBack});
  @override
  Widget build(BuildContext context) {
    final ty = laborTypes[t['task_type']] ?? laborTypes['content']!;
    final left = toI(t['left']);
    final mine = t['my_order'] as Map?;
    return SCard(
      padding: const EdgeInsets.all(12),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailPage(toI(t['id']))));
        onBack?.call();
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          MallImage(t['image'] as String?, width: 84, height: 84, radius: 14),
          Positioned(left: 6, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: ty.$3, borderRadius: BorderRadius.circular(8)), child: Icon(ty.$2, size: 13, color: Colors.white))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Sx.ink, height: 1.3)),
          const SizedBox(height: 4),
          Text('${t['publisher_name']} · ${ty.$1}${t['city'] != null ? ' · ${t['city']}' : ' · 在家可做'}', style: Sx.small),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            PriceText(toD(t['reward']), size: 19),
            const Text(' /份', style: Sx.small),
            const Spacer(),
            if (mine != null && [20, 45, 50, 55].contains(toI(mine['status'])))
              const SPill('进行中', color: Sx.blue)
            else if (mine != null && toI(mine['status']) == 80)
              const SPill('已完成', color: Sx.mint)
            else
              Text(left > 0 ? '剩 $left 个名额' : '已满', style: TextStyle(fontSize: 11, color: left > 0 && left < 10 ? Sx.coral : Sx.muted, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          SplitBar(t, compact: true),
        ])),
      ]),
    );
  }
}

// ───────────────────────── 任务详情 ─────────────────────────

class TaskDetailPage extends StatefulWidget {
  final int id;
  const TaskDetailPage(this.id, {super.key});
  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _k = GlobalKey<LoaderState<Map<String, dynamic>>>();
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      body: Loader<Map<String, dynamic>>(
        key: _k,
        load: () async => Map<String, dynamic>.from(await m.get('/labor/tasks/${widget.id}')),
        builder: (ctx, t, reload) {
          final ty = laborTypes[t['task_type']] ?? laborTypes['content']!;
          final mine = t['my_order'] as Map?;
          final active = mine != null && [10, 20, 40, 45, 50, 55].contains(toI(mine['status']));
          final done = mine != null && [60, 80].contains(toI(mine['status']));
          final req = (t['requirements'] as List?) ?? const [];
          return Column(children: [
            Expanded(child: CustomScrollView(slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 210,
                backgroundColor: Sx.ink,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(background: Stack(fit: StackFit.expand, children: [
                  MallImage(t['image'] as String?, radius: 0, full: true),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66121A33), Color(0xDD121A33)]))),
                  Positioned(left: 18, right: 18, bottom: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SPill(ty.$1, color: Colors.white, bg: ty.$3, icon: ty.$2),
                    const SizedBox(height: 8),
                    Text('${t['title']}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.3)),
                  ])),
                ])),
              ),
              SliverToBoxAdapter(child: SCard(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    PriceText(toD(t['reward']), size: 30),
                    const Text(' / 份', style: Sx.body),
                    const Spacer(),
                    Text('剩 ${t['left']} / ${t['quota']} 个名额', style: Sx.small),
                  ]),
                  const SizedBox(height: 14),
                  SplitBar(t),
                  const SizedBox(height: 10),
                  Text('平台服务费 ${toD(t['fee_pct']).toStringAsFixed(0)}% · 验收通过后立即结算', style: Sx.small),
                ]),
              )),
              SliverToBoxAdapter(child: SCard(child: Column(children: [
                _row(Icons.timer_rounded, '交付时限', '接单后 ${t['duration_hours']} 小时内'),
                _row(Icons.fact_check_rounded, '验收', '商家 ${t['review_hours']} 小时内验收，超时自动通过'),
                _row(Icons.verified_user_rounded, '门槛', ['', '手机认证', '实名认证', '活体认证', '银行卡认证'][toI(t['kyc_required']).clamp(1, 4)]),
                _row(Icons.place_rounded, '地点', t['city'] as String? ?? '线上 · 在家可做'),
                _row(Icons.event_rounded, '截止', fmtDay(DateTime.parse(t['deadline_at'] as String).toLocal()), last: true),
              ]))),
              SliverToBoxAdapter(child: SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('任务说明', style: Sx.h3),
                const SizedBox(height: 8),
                Text('${t['description']}', style: Sx.body),
                if (req.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text('交付要求', style: Sx.h3),
                  const SizedBox(height: 8),
                  for (final (i, x) in req.indexed)
                    Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 20, height: 20, alignment: Alignment.center, decoration: BoxDecoration(color: Sx.goldSoft, borderRadius: BorderRadius.circular(6)), child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Sx.gold, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$x', style: Sx.body)),
                    ])),
                ],
              ]))),
              SliverToBoxAdapter(child: SCard(child: Row(children: [
                CircleAvatar(backgroundColor: Sx.goldSoft, child: Text('${t['publisher_name']}'.characters.first, style: const TextStyle(color: Sx.gold, fontWeight: FontWeight.w900))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['publisher_name']}', style: Sx.h3),
                  Text('已发布 ${(t['publisher_stats'] as Map?)?['tasks'] ?? '-'} 个任务 · 押金已托管', style: Sx.small),
                ])),
                const SPill('押金托管', color: Sx.mint, icon: Icons.lock_rounded),
              ]))),
              const SliverToBoxAdapter(child: GuideStrip('task', margin: EdgeInsets.fromLTRB(16, 0, 16, 0))),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ])),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(color: Colors.white, boxShadow: Sx.shadow(0.06)),
                child: active
                    ? SButton('查看我的任务单', icon: Icons.assignment_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskOrderPage(toI(mine['id'])))).then((_) => reload()))
                    : done
                        ? const SButton('你已完成这个任务', onTap: null)
                        : t['eligible'] == false
                            ? SButton(t['ineligible_reason'] as String? ?? '暂不符合条件', primary: false, icon: Icons.verified_user_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycPage())).then((_) => reload()))
                            : SButton(toI(t['left']) <= 0 ? '名额已满' : '立即接单', loading: _busy, onTap: toI(t['left']) <= 0 ? null : () => _accept(m, t)),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _row(IconData i, String k, String v, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Sx.line))),
        child: Row(children: [Icon(i, size: 18, color: Sx.muted), const SizedBox(width: 10), Text(k, style: Sx.body), const Spacer(), Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: Sx.ink, fontWeight: FontWeight.w600)))]),
      );

  Future<void> _accept(MallState m, Map t) async {
    setState(() => _busy = true);
    final o = await mallRun(context, () async => Map<String, dynamic>.from(await m.post('/labor/tasks/${t['id']}/accept')), success: '接单成功，加油！');
    if (!mounted) return;
    setState(() => _busy = false);
    if (o == null) return;
    await m.refreshMe();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskOrderPage(toI(o['id']))));
    _k.currentState?.reload();
  }
}

// ───────────────────────── 我的任务 ─────────────────────────

class MyTasksPage extends StatelessWidget {
  const MyTasksPage({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Sx.bg,
        appBar: sAppBar('我的任务', actions: [
          TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())), icon: const Icon(Icons.account_balance_wallet_rounded, color: Sx.gold, size: 18), label: const Text('收益与提现', style: TextStyle(color: Sx.ink))),
        ], bottom: const TabBar(labelColor: Sx.ink, unselectedLabelColor: Sx.muted, indicatorColor: Sx.gold, indicatorSize: TabBarIndicatorSize.label, dividerColor: Colors.transparent, labelStyle: TextStyle(fontWeight: FontWeight.w800), tabs: [Tab(text: '进行中'), Tab(text: '已完成'), Tab(text: '已结束')])),
        body: const TabBarView(children: [_OrderList('active'), _OrderList('done'), _OrderList('closed')]),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final String group;
  const _OrderList(this.group);
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Loader<List<dynamic>>(
      load: () async => await m.get('/labor/orders?group=$group') as List<dynamic>,
      builder: (ctx, list, reload) => list.isEmpty
          ? ListView(children: [SEmpty(group == 'active' ? '还没有进行中的任务\n去微劳动广场挑一个吧' : '暂无记录')])
          : ListView(padding: const EdgeInsets.only(top: 10, bottom: 24), children: [
              for (final o in list)
                SCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () async {
                    await Navigator.push(ctx, MaterialPageRoute(builder: (_) => TaskOrderPage(toI(o['id']))));
                    reload();
                  },
                  child: Row(children: [
                    MallImage((o['task'] as Map?)?['image'] as String?, width: 56, height: 56, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${(o['task'] as Map?)?['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Sx.h3),
                      const SizedBox(height: 4),
                      Text(toI(o['status']) == 80 ? '现金 ${fmtMoney(toD(o['cash_amount']))} · 清偿金 ${fmtMoney(toD(o['clear_amount']))}' : '截止 ${fmtDate(DateTime.parse(o['due_at'] as String).toLocal())}', style: Sx.small),
                    ])),
                    SPill('${o['status_label']}', color: orderStatusColor(toI(o['status']))),
                  ]),
                ),
            ]),
    );
  }
}

// ───────────────────────── 任务单（提交 / 进度 / 申诉） ─────────────────────────

class TaskOrderPage extends StatefulWidget {
  final int id;
  const TaskOrderPage(this.id, {super.key});
  @override
  State<TaskOrderPage> createState() => _TaskOrderPageState();
}

class _TaskOrderPageState extends State<TaskOrderPage> {
  final _k = GlobalKey<LoaderState<Map<String, dynamic>>>();
  final _text = TextEditingController();
  final _link = TextEditingController();
  final List<String> _files = [];
  bool _busy = false;
  bool _init = false;

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('任务单'),
      body: Loader<Map<String, dynamic>>(
        key: _k,
        load: () async => Map<String, dynamic>.from(await m.get('/labor/orders/${widget.id}')),
        builder: (ctx, o, reload) {
          if (!_init) {
            _init = true;
            _text.text = (o['submission_text'] as String?) ?? '';
            _link.text = (o['submission_link'] as String?) ?? '';
            _files.addAll(((o['submission_files'] as List?) ?? const []).cast<String>());
          }
          final st = toI(o['status']);
          final t = (o['task'] as Map?) ?? const {};
          final ai = o['ai_report'] as Map?;
          final canSubmit = st == 20 || st == 45;
          return ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
            SCard(
              gradient: Sx.heroGrad,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['status_label']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_hint(o), style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
                const SizedBox(height: 16),
                _flow(st),
              ]),
            ),
            SCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailPage(toI(t['id'])))),
              child: Row(children: [
                MallImage(t['image'] as String?, width: 52, height: 52, radius: 12),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${t['title']}', maxLines: 2, style: Sx.h3),
                  Text('${t['publisher_name']} · ${fmtMoney(toD(t['reward']))}/份', style: Sx.small),
                ])),
                const Icon(Icons.chevron_right_rounded, color: Sx.muted),
              ]),
            ),
            if (st == 80)
              SCard(
                gradient: Sx.mintGrad,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('报酬已到账', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _earn('可提现现金', fmtMoney(toD(o['cash_amount']))),
                    _earn('清偿金', fmtMoney(toD(o['clear_amount']))),
                    _earn('服务费', fmtMoney(toD(o['fee']))),
                  ]),
                  if (toD(o['multiplier']) > 1) Padding(padding: const EdgeInsets.only(top: 10), child: Text('清偿金享信用加成 ×${o['multiplier']}', style: const TextStyle(color: Colors.white70, fontSize: 11.5))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), shape: const StadiumBorder()), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())), child: const Text('去提现'))),
                    const SizedBox(width: 10),
                    Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Sx.mint, shape: const StadiumBorder()), onPressed: () { m.setTab(2); Navigator.popUntil(context, (r) => r.isFirst); }, child: const Text('去清偿', style: TextStyle(fontWeight: FontWeight.w800)))),
                  ]),
                ]),
              ),
            if (ai != null)
              SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded, color: Sx.gold, size: 18),
                  const SizedBox(width: 6),
                  const Text('AI 初审报告', style: Sx.h3),
                  const Spacer(),
                  Text('${toD(o['ai_score']).toStringAsFixed(0)} 分', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: toD(o['ai_score']) >= 60 ? Sx.mint : Sx.coral)),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in (ai['checks'] as List? ?? const [])) SPill('${c['name']}', color: c['ok'] == true ? Sx.mint : Sx.coral, icon: c['ok'] == true ? Icons.check_circle_rounded : Icons.error_rounded),
                ]),
                for (final r in (ai['reasons'] as List? ?? const [])) Padding(padding: const EdgeInsets.only(top: 8), child: Text('· $r', style: const TextStyle(fontSize: 12, color: Sx.coral))),
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('已提交 ${o['ai_attempts']} 次，最多 3 次', style: Sx.small)),
              ])),
            if (canSubmit) _submitForm(m, o) else if (o['submission_text'] != null || o['submission_link'] != null)
              SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('我的交付', style: Sx.h3),
                const SizedBox(height: 8),
                if ((o['submission_text'] as String?)?.isNotEmpty == true) Text('${o['submission_text']}', style: Sx.body),
                if (o['submission_link'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${o['submission_link']}', style: const TextStyle(fontSize: 12, color: Sx.blue))),
                if (_files.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final f in _files) MallImage(f, width: 64, height: 64, radius: 10, full: true)])),
              ])),
            if (o['review_note'] != null && st == 70)
              SCard(color: const Color(0xFFFDEDEA), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('未通过原因', style: TextStyle(fontWeight: FontWeight.w800, color: Sx.coral)),
                const SizedBox(height: 6),
                Text('${o['review_note']}${o['arbitration'] != null ? '\n平台仲裁：${o['arbitration']}' : ''}', style: Sx.body),
                if (o['dispute_reason'] == null) ...[
                  const SizedBox(height: 12),
                  SButton('我有异议，申请平台仲裁', primary: false, onTap: () => _dispute(m)),
                ],
              ])),
            SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('进度记录', style: Sx.h3),
              const SizedBox(height: 10),
              for (final h in ((o['history'] as List?) ?? const []).reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(margin: const EdgeInsets.only(top: 4), width: 8, height: 8, decoration: BoxDecoration(color: orderStatusColor(toI(h['status'])), shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${h['note']}', style: const TextStyle(fontSize: 13, color: Sx.ink)),
                      Text(fmtDate(DateTime.parse(h['at'] as String).toLocal()), style: Sx.small),
                    ])),
                  ]),
                ),
            ])),
            GuideStrip(st == 80 ? 'income' : 'submit', margin: const EdgeInsets.fromLTRB(16, 0, 16, 0)),
            if (canSubmit)
              TextButton(onPressed: () => _abandon(m), child: const Text('不做了，放弃这个任务', style: TextStyle(color: Sx.muted))),
          ]);
        },
      ),
    );
  }

  Widget _earn(String k, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
        Text(k, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]));

  Widget _submitForm(MallState m, Map o) => SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('提交交付物', style: Sx.h3),
        const SizedBox(height: 4),
        const Text('写清楚你完成了什么；有作品链接请一并填写。AI 会先做原创初审。', style: Sx.small),
        const SizedBox(height: 12),
        TextField(controller: _text, maxLines: 6, maxLength: 2000, decoration: _deco('交付说明（如：已发布笔记，正文 320 字，配图 4 张…）')),
        const SizedBox(height: 4),
        TextField(controller: _link, decoration: _deco('作品链接（选填）').copyWith(prefixIcon: const Icon(Icons.link_rounded, size: 20))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in _files)
            Stack(children: [
              MallImage(f, width: 70, height: 70, radius: 12, full: true),
              Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => setState(() => _files.remove(f)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)))),
            ]),
          if (_files.length < 9)
            GestureDetector(
              onTap: () => _addDemoImage(m),
              child: Container(width: 70, height: 70, decoration: BoxDecoration(color: Sx.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Sx.line)), child: const Icon(Icons.add_photo_alternate_rounded, color: Sx.muted)),
            ),
        ]),
        const SizedBox(height: 16),
        SButton(toI(o['status']) == 45 ? '修改后重新提交' : '提交', loading: _busy, icon: Icons.send_rounded, onTap: () => _submit(m)),
      ]));

  InputDecoration _deco(String h) => InputDecoration(hintText: h, filled: true, fillColor: Sx.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), isDense: true);

  /// 演示环境：截图用示例图代替（真实环境接入相册选择 + MallState.upload 上传）
  void _addDemoImage(MallState m) {
    setState(() => _files.add(mediaImg(const ['labor_content', 'labor_survey', 'labor_visit', 'labor_label'][_files.length % 4])));
    mallToast(context, '已添加截图（演示环境使用示例图）');
  }

  String _hint(Map o) {
    final st = toI(o['status']);
    return switch (st) {
      20 => '请在 ${fmtDate(DateTime.parse(o['due_at'] as String).toLocal())} 前提交交付物',
      45 => 'AI 初审没通过，按提示修改后可以重新提交',
      50 => '商家正在验收，超时未处理会自动通过',
      55 => '平台正在仲裁，48 小时内给出结果',
      60 => '验收通过，正在结算',
      80 => '报酬已到账：现金进钱包，清偿金进清偿中心',
      70 => '这次没有通过，可以查看原因或申请仲裁',
      31 => '超过交付时限，任务已关闭',
      32 => '你已放弃这个任务',
      _ => '',
    };
  }

  Widget _flow(int st) {
    const labels = ['接单', '提交', 'AI 初审', '商家验收', '到账'];
    final step = switch (st) { 20 => 0, 45 => 1, 40 => 2, 50 || 55 => 3, 60 || 80 => 4, _ => -1 };
    return Row(children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(child: Column(children: [
          Icon(i <= step ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: i <= step ? Sx.gold : Colors.white30),
          const SizedBox(height: 3),
          Text(labels[i], style: TextStyle(fontSize: 10.5, color: i <= step ? Colors.white : Colors.white38, fontWeight: FontWeight.w600)),
        ])),
    ]);
  }

  Future<void> _submit(MallState m) async {
    setState(() => _busy = true);
    final r = await mallRun(context, () async => Map<String, dynamic>.from(await m.post('/labor/orders/${widget.id}/submit', {'text': _text.text.trim(), 'link': _link.text.trim().isEmpty ? null : _link.text.trim(), 'files': _files})));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) return;
    mallToast(context, toI(r['status']) == 50 ? 'AI 初审通过（${toD(r['ai_score']).toStringAsFixed(0)} 分），等待商家验收' : 'AI 初审未通过，请按提示修改', ok: toI(r['status']) == 50);
    _k.currentState?.reload();
  }

  Future<void> _dispute(MallState m) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(context: context, builder: (dc) => AlertDialog(
      title: const Text('申请平台仲裁'),
      content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: '说明你的理由（至少 6 字），可补充证据链接')),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dc, c.text), child: const Text('提交'))],
    ));
    if (reason == null || !mounted) return;
    await mallRun(context, () => m.post('/labor/orders/${widget.id}/dispute', {'reason': reason}), success: '已提交，平台将在 48 小时内仲裁');
    _k.currentState?.reload();
  }

  Future<void> _abandon(MallState m) async {
    final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(title: const Text('确定放弃？'), content: const Text('放弃后名额会释放给其他人。'), actions: [TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('再想想')), FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('放弃'))]));
    if (ok != true || !mounted) return;
    await mallRun(context, () => m.post('/labor/orders/${widget.id}/abandon'), success: '已放弃');
    _k.currentState?.reload();
  }
}
