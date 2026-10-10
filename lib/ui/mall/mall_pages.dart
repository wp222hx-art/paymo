import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/mall_state.dart';
import '../widgets/common.dart';
import 'clear_pages.dart';
import 'labor_pages.dart' show TaskCard;
import 'mall_order_pages.dart';
import 'mall_widgets.dart';

// ───────────────────────── 星光首页 ─────────────────────────

class MallHomePage extends StatefulWidget {
  const MallHomePage({super.key});
  @override
  State<MallHomePage> createState() => _MallHomePageState();
}

class _MallHomePageState extends State<MallHomePage> {
  Future<List<dynamic>>? _hot;
  Future<List<dynamic>>? _feed;
  Future<List<dynamic>>? _tasks;
  MallState? _bound;

  void _load(MallState m) {
    _bound = m;
    _hot = m.products(sort: 'commission', size: 10);
    _feed = m.products(sort: 'sales', size: 40);
    _tasks = m.get('/labor/tasks').then((v) => (v as List<dynamic>).take(3).toList());
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    if (m.ready && m.me != null && _bound != m) _load(m);
    return Scaffold(
      backgroundColor: Sx.bg,
      body: MallGate(builder: (ctx, m) => RefreshIndicator(
        color: Sx.gold,
        onRefresh: () async {
          await m.refreshMe();
          setState(() => _load(m));
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(m)),
          SliverToBoxAdapter(child: _searchBar(context)),
          SliverToBoxAdapter(child: _FlowSteps(m)),
          SliverToBoxAdapter(child: _LaborEntry(m)),
          SliverToBoxAdapter(child: _Banners()),
          const SliverToBoxAdapter(child: SHeader('逛逛好物', sub: '本来就要买的东西，在这里买还能清偿账单')),
          SliverToBoxAdapter(child: _CategoryGrid(m)),
          SliverToBoxAdapter(child: SHeader('返得多 · 精选', sub: '同样的消费，返还的清偿金更多', action: '更多', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListPage(title: '返得多 · 精选', sort: 'commission'))))),
          SliverToBoxAdapter(child: _HotRow(future: _hot)),
          SliverToBoxAdapter(child: SHeader('今天可以做的微劳动', sub: '报酬一份现金一份清偿金', action: '全部', onAction: () => m.setTab(1))),
          SliverToBoxAdapter(child: FutureBuilder<List<dynamic>>(future: _tasks, builder: (ctx, s) => s.hasData ? Column(children: [for (final t in s.data!) TaskCard(t as Map, onBack: () => setState(() => _load(m)))]) : const SizedBox(height: 60))),
          SliverToBoxAdapter(child: SHeader('看视频，1 分钟上手', sub: '真人演示每一个环节', action: '全部', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuideCenterPage())))),
          SliverToBoxAdapter(child: SizedBox(
            height: 228,
            child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: m.guides.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, i) => GuideCard(m.guides[i])),
          )),
          SliverToBoxAdapter(child: _PartnerBanks(m)),
          const SliverToBoxAdapter(child: SHeader('大家都在买')),
          _FeedGrid(future: _feed),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ]),
      )),
    );
  }

  Widget _searchBar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListPage(title: '搜索', search: true))),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: Sx.shadow(0.04)),
            child: const Row(children: [
              Icon(Icons.search_rounded, color: Sx.muted, size: 20),
              SizedBox(width: 8),
              Text('搜咖啡、水果、电影票、纸巾…', style: TextStyle(color: Sx.muted, fontSize: 13.5)),
            ]),
          ),
        ),
      );
}

/// 首页头图：品牌氛围 + 我的清偿概览
class _Hero extends StatelessWidget {
  final MallState m;
  const _Hero(this.m);
  @override
  Widget build(BuildContext context) {
    final ov = m.overview ?? const {};
    final bal = (ov['balance'] as Map?) ?? const {};
    final bills = (ov['bills'] as Map?) ?? const {};
    final hasBills = toI(bills['count']) + toI(bills['settled']) > 0;
    final top = MediaQuery.of(context).padding.top;
    return Stack(children: [
      SizedBox(
        height: 300 + top,
        width: double.infinity,
        child: Stack(fit: StackFit.expand, children: [
          MallImage(mediaImg('brand_hero'), radius: 0, full: true, alignment: const Alignment(0.3, 0)),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99121A33), Color(0x33121A33), Color(0xEE121A33)], stops: [0, 0.45, 1]))),
        ]),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(20, top + 14, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 30, height: 30, decoration: const BoxDecoration(gradient: Sx.goldGrad, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17)),
            const SizedBox(width: 8),
            const Text('星光云', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const Spacer(),
            _IconBtn(Icons.mail_outline_rounded, badge: toI(ov['unread_letters']), tip: '银行回函', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LettersPage()))),
            _IconBtn(Icons.receipt_long_rounded, tip: '我的订单', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MallOrdersPage()))),
          ]),
          const SizedBox(height: 26),
          const Text('会花钱，\n也会轻松清偿。', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.25)),
          const SizedBox(height: 8),
          const Text('日常消费返还清偿金，帮你一点点偿清银行账单', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => playGuide(context, 'intro'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.play_circle_fill_rounded, color: Sx.gold, size: 22),
                SizedBox(width: 6),
                Text('20 秒看懂星光云', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 250 + top, 16, 0),
        child: SCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => hasBills ? const ClearCenterPage() : const BankQueryPage())),
          child: hasBills
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('我的清偿金', style: TextStyle(fontSize: 12, color: Sx.muted)),
                    const Spacer(),
                    SPill('信用 ${ov['credit_score'] ?? '-'}', color: Sx.gold, icon: Icons.trending_up_rounded),
                  ]),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(fmtMoney(toD(bal['available'])), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Sx.ink, letterSpacing: -0.5)),
                    const SizedBox(width: 8),
                    if (toD(bal['pending_dp']) > 0) Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('+${fmtMoney(toD(bal['pending_dp']))} 待到账', style: const TextStyle(fontSize: 11.5, color: Sx.mint, fontWeight: FontWeight.w700))),
                    const Spacer(),
                    SizedBox(height: 36, child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Sx.ink, padding: const EdgeInsets.symmetric(horizontal: 16)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClearCenterPage())),
                      child: const Text('去清偿', style: TextStyle(fontWeight: FontWeight.w800)),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(minHeight: 7, value: toD(bills['progress']).clamp(0.0, 1.0), backgroundColor: Sx.line, color: Sx.mint)),
                  const SizedBox(height: 6),
                  Text('已偿清 ${(toD(bills['progress']) * 100).toStringAsFixed(1)}% · 剩余待清偿 ${fmtMoney(toD(bills['outstanding']))} · ${bills['count']} 笔账单', style: Sx.small),
                ])
              : Row(children: [
                  Container(width: 46, height: 46, decoration: BoxDecoration(color: Sx.blueSoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.account_balance_rounded, color: Sx.blue)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('先看看我名下有哪些账单', style: Sx.h3),
                    SizedBox(height: 3),
                    Text('输入手机号，合作银行实时查询，30 秒完成', style: Sx.small),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: Sx.muted),
                ]),
        ),
      ),
    ]);
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final int badge;
  final String tip;
  final VoidCallback onTap;
  const _IconBtn(this.icon, {this.badge = 0, required this.tip, required this.onTap});
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        IconButton(tooltip: tip, onPressed: onTap, icon: Icon(icon, color: Colors.white)),
        if (badge > 0) Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Sx.coral, shape: BoxShape.circle))),
      ]);
}

/// 微劳动入口
class _LaborEntry extends StatelessWidget {
  final MallState m;
  const _LaborEntry(this.m);
  @override
  Widget build(BuildContext context) {
    return SCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: EdgeInsets.zero,
      onTap: () => m.setTab(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Sx.r),
        child: Stack(children: [
          SizedBox(height: 104, width: double.infinity, child: MallImage(mediaImg('labor_banner'), radius: 0, full: true)),
          Container(height: 104, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xEE1B2440), Color(0x111B2440)], stops: [0.25, 1]))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('微劳动 · 碎片时间赚清偿金', style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('拍视频 · 填问卷 · 探门店 · 在家标注', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                const SizedBox(height: 8),
                Row(children: [
                  const SPill('一份现金', color: Colors.white, bg: Color(0x33C9A063)),
                  const SizedBox(width: 6),
                  const SPill('一份清偿金', color: Colors.white, bg: Color(0x332FA37A)),
                  if (toI(m.laborSummary?['active']) > 0) ...[const SizedBox(width: 6), SPill('${m.laborSummary?['active']} 个进行中', color: Sx.gold, bg: Colors.white)],
                ]),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(gradient: Sx.goldGrad, borderRadius: BorderRadius.circular(20)), child: const Text('去接单', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// 四步流程：每一步可点开视频
class _FlowSteps extends StatelessWidget {
  final MallState m;
  const _FlowSteps(this.m);
  @override
  Widget build(BuildContext context) {
    const steps = [
      ('bank', Icons.account_balance_rounded, '查账单', '手机号一查'),
      ('mall', Icons.shopping_bag_rounded, '日常购物', '每单都返'),
      ('credit', Icons.eco_rounded, '清偿金到账', '收货后到账'),
      ('clear', Icons.task_alt_rounded, '一键清偿', '银行核减'),
    ];
    return SCard(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Column(children: [
        const Row(children: [
          SizedBox(width: 10),
          Text('四步轻松清偿', style: Sx.h3),
          Spacer(),
          Text('点任一步看视频', style: Sx.small),
          SizedBox(width: 10),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => playGuide(context, steps[i].$1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(color: i == 3 ? Sx.mintSoft : Sx.goldSoft, borderRadius: BorderRadius.circular(16)), child: Icon(steps[i].$2, color: i == 3 ? Sx.mint : Sx.gold, size: 24)),
                    Positioned(right: -4, bottom: -4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(m.watchedGuides.contains(steps[i].$1) ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded, size: 16, color: m.watchedGuides.contains(steps[i].$1) ? Sx.mint : Sx.ink))),
                  ]),
                  const SizedBox(height: 8),
                  Text(steps[i].$3, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Sx.ink)),
                  const SizedBox(height: 1),
                  Text(steps[i].$4, style: const TextStyle(fontSize: 10, color: Sx.muted)),
                ]),
              ),
            )),
            if (i < steps.length - 1) const Padding(padding: EdgeInsets.only(bottom: 34), child: Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Sx.line)),
          ],
        ]),
      ]),
    );
  }
}

class _Banners extends StatefulWidget {
  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  final _pc = PageController(viewportFraction: 0.92);
  int _i = 0;
  Timer? _t;
  static const items = [
    ('home_banner_1', '生鲜到家', '水果蔬菜 · 每单返清偿金', '生鲜水果'),
    ('home_banner_2', '吃点好的', '咖啡茶饮 · 餐厅套餐 · 最高返 5 倍', '美食饮品'),
    ('home_banner_3', '周末去看场电影', '电影 · KTV · 健身，都能返', '休闲娱乐'),
    ('home_banner_4', '家里缺点什么', '纸巾洗衣液，囤货也能清偿', '日用清洁'),
  ];
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pc.hasClients) return;
      _pc.animateToPage((_i + 1) % items.length, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pc,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) {
              final b = items[i];
              return GestureDetector(
                onTap: () {
                  final c = m.categories.where((x) => x['name'] == b.$4).firstOrNull;
                  if (c != null) Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryPage(initial: toI(c['id']))));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(Sx.r),
                    child: Stack(fit: StackFit.expand, children: [
                      MallImage(mediaImg(b.$1), radius: 0, full: true),
                      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xCC121A33), Color(0x00121A33)], stops: [0.1, 0.75]))),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(b.$2, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          Text(b.$3, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 10),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Sx.gold, borderRadius: BorderRadius.circular(12)), child: const Text('去看看', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < items.length; i++) AnimatedContainer(duration: const Duration(milliseconds: 250), width: i == _i ? 16 : 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: i == _i ? Sx.ink : Sx.line, borderRadius: BorderRadius.circular(3))),
        ]),
      ]),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final MallState m;
  const _CategoryGrid(this.m);
  @override
  Widget build(BuildContext context) {
    final cats = m.categories;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 130, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82),
        itemCount: cats.length,
        itemBuilder: (_, i) {
          final c = cats[i];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryPage(initial: toI(c['id'])))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(fit: StackFit.expand, children: [
                MallImage(c['image'] as String?, emoji: c['icon'] as String? ?? '🛍️', radius: 0),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.4, 1], colors: [Colors.transparent, Color(0xD9121A33)]))),
                Positioned(left: 10, right: 6, bottom: 9, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c['name']}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('${c['product_count']} 件好物', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ])),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _HotRow extends StatelessWidget {
  final Future<List<dynamic>>? future;
  const _HotRow({this.future});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 236,
        child: FutureBuilder<List<dynamic>>(
          future: future,
          builder: (ctx, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator(color: Sx.gold));
            final list = s.data!;
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: 148, child: ProductTile(list[i] as Map<String, dynamic>, compact: true)),
            );
          },
        ),
      );
}

class _PartnerBanks extends StatelessWidget {
  final MallState m;
  const _PartnerBanks(this.m);
  @override
  Widget build(BuildContext context) {
    final banks = (m.stats?['banks'] as List?) ?? const [];
    return SCard(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankQueryPage())),
      child: Column(children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Sx.r)),
          child: SizedBox(height: 96, width: double.infinity, child: Stack(fit: StackFit.expand, children: [
            MallImage(mediaImg('partner_banks'), radius: 0, full: true),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xE61B2440), Color(0x401B2440)]))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('合作银行与持牌机构', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('累计帮用户偿清 ${fmtMoney(toD(m.stats?['cleared_amount']))}', style: const TextStyle(color: Sx.gold, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ])),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final b in banks) BankChip(b as Map),
          ]),
        ),
      ]),
    );
  }
}

class BankChip extends StatelessWidget {
  final Map b;
  const BankChip(this.b, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = Color(int.parse((b['color'] as String).substring(1), radix: 16) | 0xFF000000);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: BoxDecoration(color: Sx.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        BankLogo(b, size: 20),
        const SizedBox(width: 5),
        Text('${b['name']}', style: TextStyle(fontSize: 11, color: c.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class BankLogo extends StatelessWidget {
  final Map? b;
  final double size;
  const BankLogo(this.b, {super.key, this.size = 36});
  @override
  Widget build(BuildContext context) {
    final c = b == null ? Sx.ink : Color(int.parse((b!['color'] as String).substring(1), radix: 16) | 0xFF000000);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(b?['short'] as String? ?? '银', style: TextStyle(color: Colors.white, fontSize: size * 0.48, fontWeight: FontWeight.w900)),
    );
  }
}

class _FeedGrid extends StatelessWidget {
  final Future<List<dynamic>>? future;
  const _FeedGrid({this.future});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        future: future,
        builder: (ctx, s) {
          if (!s.hasData) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: Sx.gold))));
          final list = s.data!;
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 230, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.6),
              delegate: SliverChildBuilderDelegate((_, i) => ProductTile(list[i] as Map<String, dynamic>), childCount: list.length),
            ),
          );
        },
      );
}

/// 商品卡
class ProductTile extends StatelessWidget {
  final Map<String, dynamic> p;
  final bool compact;
  const ProductTile(this.p, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final id = toI(p['id']);
    final q = m.quotes[id];
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(id))),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Sx.shadow(0.04)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: compact ? 1.25 : 1,
            child: Stack(fit: StackFit.expand, children: [
              MallImage(p['image'] as String?, emoji: p['emoji'] as String? ?? '🛍️', radius: 0),
              if (q != null) Positioned(left: 8, bottom: 8, child: ReturnBadge(toD(q['dp_amount']), small: true, onImage: true)),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.3, color: Sx.ink)),
                if (!compact) ...[
                  const SizedBox(height: 3),
                  Text('${p['subtitle']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Sx.muted)),
                ],
                const Spacer(),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Flexible(child: PriceText(toD(p['price']), size: 16, original: compact ? null : (p['original_price'] == null ? null : toD(p['original_price'])))),
                  const Spacer(),
                  if (!compact) Text('已售 ${_short(toI(p['sales']))}', style: const TextStyle(fontSize: 10, color: Sx.muted)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

String _short(int n) => n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万' : '$n';

// ───────────────────────── 分类页 ─────────────────────────

class CategoryPage extends StatefulWidget {
  final int? initial;
  final bool embedded;
  const CategoryPage({super.key, this.initial, this.embedded = false});
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  int? _top;
  int? _sub;
  String _sort = '';
  Future<List<dynamic>>? _f;

  void _load(MallState m) => _f = m.products(categoryId: _sub ?? _top, sort: _sort.isEmpty ? null : _sort);

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final cats = m.categories;
    if (cats.isNotEmpty && _top == null) {
      _top = widget.initial != null && cats.any((c) => toI(c['id']) == widget.initial) ? widget.initial : toI(cats.first['id']);
      _load(m);
    }
    final cur = cats.where((c) => toI(c['id']) == _top).firstOrNull;
    final subs = (cur?['children'] as List?) ?? const [];
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: AppBar(
        backgroundColor: Sx.bg,
        foregroundColor: Sx.ink,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('全部分类', style: TextStyle(fontWeight: FontWeight.w800, color: Sx.ink)),
        actions: [IconButton(icon: const Icon(Icons.search_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListPage(title: '搜索', search: true))))],
      ),
      body: MallGate(builder: (ctx, m) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 左侧大类
        Container(
          width: 88,
          color: Colors.white,
          child: ListView(children: [
            for (final c in cats)
              InkWell(
                onTap: () => setState(() {
                  _top = toI(c['id']);
                  _sub = null;
                  _load(m);
                }),
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(color: toI(c['id']) == _top ? Sx.bg : Colors.white, border: Border(left: BorderSide(color: toI(c['id']) == _top ? Sx.gold : Colors.transparent, width: 3))),
                  alignment: Alignment.center,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${c['icon']}', style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text('${c['name']}', style: TextStyle(fontSize: 11.5, fontWeight: toI(c['id']) == _top ? FontWeight.w800 : FontWeight.w500, color: toI(c['id']) == _top ? Sx.ink : Sx.inkSoft)),
                  ]),
                ),
              ),
          ]),
        ),
        Expanded(
          child: CustomScrollView(slivers: [
            if (cur != null)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(height: 92, child: Stack(fit: StackFit.expand, children: [
                    MallImage(cur['image'] as String?, radius: 0, full: true),
                    const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xCC121A33), Color(0x00121A33)]))),
                    Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${cur['name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('${cur['product_count']} 件好物 · 每单返清偿金', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ])),
                  ])),
                ),
              )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                _subChip('全部', null, m),
                for (final s in subs) _subChip('${s['icon']} ${s['name']}', toI(s['id']), m),
              ]),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(children: [
                for (final s in const [('', '综合'), ('sales', '销量'), ('commission', '返得多'), ('price_asc', '价格低')])
                  Padding(padding: const EdgeInsets.only(right: 16), child: GestureDetector(
                    onTap: () => setState(() {
                      _sort = s.$1;
                      _load(m);
                    }),
                    child: Text(s.$2, style: TextStyle(fontSize: 12.5, fontWeight: _sort == s.$1 ? FontWeight.w800 : FontWeight.w500, color: _sort == s.$1 ? Sx.ink : Sx.muted)),
                  )),
              ]),
            )),
            FutureBuilder<List<dynamic>>(
              future: _f,
              builder: (ctx, s) {
                if (!s.hasData) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: Sx.gold))));
                final list = s.data!;
                if (list.isEmpty) return const SliverToBoxAdapter(child: SEmpty('这里暂时没有商品'));
                return SliverList(delegate: SliverChildBuilderDelegate((_, i) => _RowProduct(list[i] as Map<String, dynamic>), childCount: list.length));
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ]),
        ),
      ])),
    );
  }

  Widget _subChip(String label, int? id, MallState m) {
    final sel = _sub == id;
    return GestureDetector(
      onTap: () => setState(() {
        _sub = id;
        _load(m);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: sel ? Sx.ink : Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: TextStyle(fontSize: 12, color: sel ? Colors.white : Sx.inkSoft, fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

/// 列表行商品
class _RowProduct extends StatelessWidget {
  final Map<String, dynamic> p;
  const _RowProduct(this.p);
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final id = toI(p['id']);
    final q = m.quotes[id];
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(id))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MallImage(p['image'] as String?, emoji: p['emoji'] as String? ?? '🛍️', width: 92, height: 92, radius: 12),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(
            height: 92,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Sx.ink, height: 1.3)),
              const SizedBox(height: 2),
              Text('${p['subtitle']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Sx.small),
              const Spacer(),
              if (q != null) ReturnBadge(toD(q['dp_amount']), small: true),
              const SizedBox(height: 4),
              Row(children: [
                PriceText(toD(p['price']), size: 16),
                const Spacer(),
                InkWell(
                  onTap: () => mallRun(context, () => m.addToCart(id, 1), success: '已加入购物车'),
                  child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: Sx.ink, shape: BoxShape.circle), child: const Icon(Icons.add_rounded, color: Colors.white, size: 18)),
                ),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ───────────────────────── 搜索 / 列表 ─────────────────────────

class ProductListPage extends StatefulWidget {
  final String title;
  final String? sort;
  final bool search;
  const ProductListPage({super.key, required this.title, this.sort, this.search = false});
  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _kw = TextEditingController();
  Future<List<dynamic>>? _f;
  static const hot = ['咖啡', '水果', '电影票', '纸巾', '牛奶', '火锅', '洗衣液', '话费'];

  @override
  void initState() {
    super.initState();
    if (!widget.search) _f = context.read<MallState>().products(sort: widget.sort);
  }

  @override
  void dispose() {
    _kw.dispose();
    super.dispose();
  }

  void _go(String k) => setState(() {
        _kw.text = k;
        _f = context.read<MallState>().products(keyword: k);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: AppBar(
        backgroundColor: Sx.bg,
        foregroundColor: Sx.ink,
        elevation: 0,
        titleSpacing: 0,
        title: widget.search
            ? Container(
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: TextField(controller: _kw, autofocus: true, textInputAction: TextInputAction.search, onSubmitted: _go, decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: '搜索商品 / 品牌', icon: Icon(Icons.search_rounded, size: 20))),
              )
            : Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, color: Sx.ink)),
      ),
      body: _f == null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('大家都在搜', style: Sx.h3),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final k in hot) ActionChip(label: Text(k), backgroundColor: Colors.white, side: BorderSide.none, shape: const StadiumBorder(), onPressed: () => _go(k))]),
              ]),
            )
          : FutureBuilder<List<dynamic>>(
              future: _f,
              builder: (ctx, s) {
                if (!s.hasData) return const Center(child: CircularProgressIndicator(color: Sx.gold));
                if (s.data!.isEmpty) return const SEmpty('没有找到相关商品，换个词试试');
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 230, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.6),
                  itemCount: s.data!.length,
                  itemBuilder: (_, i) => ProductTile(s.data![i] as Map<String, dynamic>),
                );
              },
            ),
    );
  }
}

// ───────────────────────── 商品详情 ─────────────────────────

class ProductDetailPage extends StatefulWidget {
  final int id;
  const ProductDetailPage(this.id, {super.key});
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _qty = 1;
  late Future<Map<String, dynamic>> _f;

  @override
  void initState() {
    super.initState();
    _f = context.read<MallState>().product(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: Sx.gold));
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          final p = snap.data!;
          final q = m.quotes[widget.id];
          final stock = toI(p['stock']);
          final ret = q == null ? 0.0 : toD(q['dp_amount']) * _qty;
          return Column(children: [
            Expanded(child: CustomScrollView(slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.width.clamp(0, 520).toDouble(),
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Sx.ink,
                leading: Padding(padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundColor: Colors.white.withValues(alpha: 0.9), child: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Sx.ink, size: 20), onPressed: () => Navigator.pop(context)))),
                actions: [
                  Padding(padding: const EdgeInsets.all(8), child: CircleAvatar(backgroundColor: Colors.white.withValues(alpha: 0.9), child: IconButton(icon: Badge(isLabelVisible: m.cartCount > 0, label: Text('${m.cartCount}'), child: const Icon(Icons.shopping_bag_outlined, color: Sx.ink, size: 20)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()))))),
                ],
                flexibleSpace: FlexibleSpaceBar(background: MallImage(p['image'] as String?, emoji: p['emoji'] as String? ?? '🛍️', radius: 0, full: true)),
              ),
              SliverToBoxAdapter(child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    PriceText(toD(p['price']), size: 28, original: p['original_price'] == null ? null : toD(p['original_price'])),
                    const Spacer(),
                    Text('已售 ${_short(toI(p['sales']))}', style: Sx.small),
                  ]),
                  const SizedBox(height: 10),
                  Text('${p['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Sx.ink, height: 1.35)),
                  const SizedBox(height: 6),
                  Text('${p['subtitle']}', style: Sx.body),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, children: [
                    SPill('${p['category_name']}', color: Sx.inkSoft, bg: Sx.bg),
                    const SPill('正品保障', color: Sx.blue, icon: Icons.verified_rounded),
                    const SPill('7 天售后', color: Sx.inkSoft, bg: Sx.bg),
                  ]),
                ]),
              )),
              if (q != null)
                SliverToBoxAdapter(child: SCard(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  gradient: const LinearGradient(colors: [Color(0xFFEAF7F1), Color(0xFFF7FBF9)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 36, height: 36, decoration: const BoxDecoration(gradient: Sx.mintGrad, shape: BoxShape.circle), child: const Icon(Icons.eco_rounded, color: Colors.white, size: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('买这件，返 ${fmtMoney(ret)} 清偿金', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Sx.mint)),
                        Text('可直接用来清偿你的银行账单', style: Sx.small.copyWith(color: Sx.inkSoft)),
                      ])),
                    ]),
                    const SizedBox(height: 12),
                    _kvRow('平台返佣', fmtMoney(toD(q['commission']) * _qty)),
                    _kvRow('我的返还倍率', '× ${toD(q['multiplier']).toStringAsFixed(1)}（信用越好越高）'),
                    _kvRow('到账时间', '确认收货 7 天后自动到账'),
                  ]),
                )),
              SliverToBoxAdapter(child: GuideStrip('mall', margin: const EdgeInsets.fromLTRB(16, 12, 16, 0))),
              SliverToBoxAdapter(child: SCard(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('商品详情', style: Sx.h3),
                  const SizedBox(height: 10),
                  Text('${p['description'] ?? ''}', style: Sx.body),
                  const SizedBox(height: 14),
                  MallImage(p['image'] as String?, full: true, radius: 12),
                ]),
              )),
            ])),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(color: Colors.white, boxShadow: Sx.shadow(0.06)),
                child: Row(children: [
                  Container(
                    decoration: BoxDecoration(color: Sx.bg, borderRadius: BorderRadius.circular(22)),
                    child: Row(children: [
                      IconButton(visualDensity: VisualDensity.compact, onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove_rounded, size: 18)),
                      Text('$_qty', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      IconButton(visualDensity: VisualDensity.compact, onPressed: _qty < stock && _qty < 99 ? () => setState(() => _qty++) : null, icon: const Icon(Icons.add_rounded, size: 18)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: SButton('加入购物车', primary: false, onTap: stock <= 0 ? null : () => mallRun(context, () => m.addToCart(widget.id, _qty), success: '已加入购物车'))),
                  const SizedBox(width: 8),
                  Expanded(child: SButton(stock <= 0 ? '已售罄' : '立即购买', onTap: stock <= 0 ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutPage(items: [{'product_id': widget.id, 'qty': _qty}]))))),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _kvRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [SizedBox(width: 92, child: Text(k, style: Sx.small)), Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, color: Sx.ink, fontWeight: FontWeight.w600)))]),
      );
}

// ───────────────────────── 购物车 ─────────────────────────

class CartPage extends StatefulWidget {
  final bool embedded;
  const CartPage({super.key, this.embedded = false});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<dynamic>? _items;
  int _seen = -1;

  Future<void> _reload() async {
    final l = await mallRun(context, () => context.read<MallState>().cart());
    if (mounted) setState(() => _items = l ?? []);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    if (m.ready && _seen != m.cartCount) {
      _seen = m.cartCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }
    final items = _items;
    final checked = items?.where((x) => toI(x['checked']) == 1 && x['available'] == true).toList() ?? [];
    final total = checked.fold(0.0, (a, x) => a + toD(x['subtotal']));
    final ret = checked.fold(0.0, (a, x) => a + toD(x['dp_amount']));
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: AppBar(backgroundColor: Sx.bg, foregroundColor: Sx.ink, elevation: 0, automaticallyImplyLeading: !widget.embedded, title: Text('购物车${items == null || items.isEmpty ? '' : '（${items.length}）'}', style: const TextStyle(fontWeight: FontWeight.w800, color: Sx.ink))),
      body: items == null
          ? const Center(child: CircularProgressIndicator(color: Sx.gold))
          : items.isEmpty
              ? ListView(children: [const SizedBox(height: 40), SEmpty('购物车空空的\n去挑点本来就要买的东西吧', img: 'cart_empty', action: '去逛逛', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryPage())))])
              : RefreshIndicator(
                  color: Sx.gold,
                  onRefresh: _reload,
                  child: ListView(padding: const EdgeInsets.only(top: 4, bottom: 16), children: [
                    for (final x in items)
                      SCard(
                        padding: const EdgeInsets.fromLTRB(4, 10, 10, 10),
                        child: Row(children: [
                          Checkbox(
                            shape: const CircleBorder(),
                            activeColor: Sx.ink,
                            value: toI(x['checked']) == 1 && x['available'] == true,
                            onChanged: x['available'] == true ? (v) async { await mallRun(context, () => m.updateCart(toI(x['cart_item_id']), checked: v)); } : null,
                          ),
                          MallImage(x['image'] as String?, emoji: x['emoji'] as String? ?? '🛍️', width: 76, height: 76, radius: 12),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(x['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Sx.ink)),
                            const SizedBox(height: 5),
                            if (x['available'] != true) const SPill('已下架或库存不足', color: Sx.coral) else ReturnBadge(toD(x['dp_amount']), small: true),
                            const SizedBox(height: 5),
                            Row(children: [
                              PriceText(toD(x['price']), size: 15),
                              const Spacer(),
                              _qtyBtn(Icons.remove_rounded, toI(x['qty']) > 1 ? () => mallRun(context, () => m.updateCart(toI(x['cart_item_id']), qty: toI(x['qty']) - 1)) : null),
                              SizedBox(width: 26, child: Text('${x['qty']}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
                              _qtyBtn(Icons.add_rounded, () => mallRun(context, () => m.updateCart(toI(x['cart_item_id']), qty: toI(x['qty']) + 1))),
                            ]),
                          ])),
                          IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Sx.muted), onPressed: () => mallRun(context, () => m.removeCart(toI(x['cart_item_id'])))),
                        ]),
                      ),
                    GuideStrip('pay', margin: const EdgeInsets.fromLTRB(16, 4, 16, 0)),
                  ]),
                ),
      bottomNavigationBar: items == null || items.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
                decoration: BoxDecoration(color: Colors.white, boxShadow: Sx.shadow(0.06)),
                child: Row(children: [
                  Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Text('合计 ', style: TextStyle(color: Sx.ink, fontWeight: FontWeight.w700)), PriceText(total, size: 19)]),
                    Text('可返清偿金 ${fmtMoney(ret)}', style: const TextStyle(fontSize: 11.5, color: Sx.mint, fontWeight: FontWeight.w800)),
                  ])),
                  SizedBox(width: 140, child: SButton('去结算（${checked.length}）', onTap: checked.isEmpty ? null : () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutPage(items: [for (final x in checked) {'product_id': toI(x['product_id']), 'qty': toI(x['qty'])}], fromCart: true)));
                    _reload();
                  })),
                ]),
              ),
            ),
    );
  }

  Widget _qtyBtn(IconData i, VoidCallback? onTap) => InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 26, height: 26, decoration: BoxDecoration(color: Sx.bg, shape: BoxShape.circle), child: Icon(i, size: 15, color: onTap == null ? Sx.line : Sx.ink)));
}
