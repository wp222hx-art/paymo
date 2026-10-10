import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/mall_state.dart';
import '../widgets/common.dart';
import 'mall_order_pages.dart' show MallOrdersPage, sAppBar;
import 'mall_pages.dart' show BankLogo, CategoryPage;
import 'mall_widgets.dart';

Map? bankOf(MallState m, String? code, [String? name]) {
  final list = (m.stats?['banks'] as List?) ?? const [];
  return list.cast<Map>().where((b) => b['code'] == code || (name != null && name.startsWith(b['name'] as String))).firstOrNull;
}

// ───────────────────────── 清偿中心 ─────────────────────────

class ClearCenterPage extends StatefulWidget {
  final bool embedded;
  const ClearCenterPage({super.key, this.embedded = false});
  @override
  State<ClearCenterPage> createState() => _ClearCenterPageState();
}

class _ClearCenterPageState extends State<ClearCenterPage> {
  final _k = GlobalKey<LoaderState<List<dynamic>>>();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && toI(context.read<MallState>().overview?['clearing']) > 0) _k.currentState?.reload();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: AppBar(
        backgroundColor: Sx.bg,
        foregroundColor: Sx.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('清偿中心', style: TextStyle(fontWeight: FontWeight.w800, color: Sx.ink)),
        actions: [
          IconButton(tooltip: '银行回函', icon: const Icon(Icons.mail_outline_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LettersPage()))),
          IconButton(tooltip: '偿清证明', icon: const Icon(Icons.workspace_premium_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificatesPage()))),
        ],
      ),
      body: MallGate(builder: (ctx, m) => Loader<List<dynamic>>(
        key: _k,
        load: () async {
          await m.refreshMe();
          return Future.wait([m.commissions(), m.debts(), m.clearances()]);
        },
        builder: (ctx, r, reload) {
          final cm = r[0] as Map<String, dynamic>;
          final sum = cm['summary'] as Map<String, dynamic>;
          final debts = r[1] as List<dynamic>;
          final cls = r[2] as List<dynamic>;
          final ov = m.overview ?? const {};
          final bal = (ov['balance'] as Map?) ?? const {};
          final bills = (ov['bills'] as Map?) ?? const {};
          final avail = toD(bal['available']);
          final open = debts.where((d) => toI(d['status']) != 3).toList();
          final canClear = avail > 0 && open.any((d) => d['clearing'] != true);
          final active = cls.where((c) => [10, 20, 30].contains(toI(c['status']))).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
            // 余额卡
            SCard(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              padding: EdgeInsets.zero,
              gradient: Sx.heroGrad,
              child: Stack(children: [
                Positioned(right: -10, top: -10, bottom: 0, child: Opacity(opacity: 0.22, child: MallImage(mediaImg('clear_center'), width: 200, radius: 0, full: true))),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('可用清偿金', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      const SizedBox(width: 6),
                      GestureDetector(onTap: () => _explain(context), child: const Icon(Icons.help_outline_rounded, size: 15, color: Colors.white54)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditPage())),
                        child: SPill('信用 ${ov['credit_score'] ?? '-'}', color: Sx.gold, bg: Colors.white12, icon: Icons.trending_up_rounded),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(fmtMoney(avail), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 14),
                    Row(children: [
                      _stat('待收货', fmtMoney(toD(sum['estimated_dp']))),
                      _stat('保障期中', fmtMoney(toD(sum['pending_dp']))),
                      _stat('累计到账', fmtMoney(toD(sum['settled_dp']))),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: SButton(open.isEmpty ? (debts.isEmpty ? '先导入银行账单' : '导入更多账单') : '一键清偿', gold: true, icon: open.isEmpty ? Icons.account_balance_rounded : Icons.task_alt_rounded, onTap: open.isEmpty ? () => _toBank(context, reload) : (canClear ? () => _clearSheet(context, m, open, avail, reload) : null))),
                      const SizedBox(width: 10),
                      SizedBox(width: 110, child: _ghost('去购物', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryPage())))),
                    ]),
                    if (open.isNotEmpty && !canClear)
                      Padding(padding: const EdgeInsets.only(top: 10), child: Text(avail <= 0 ? '清偿金到账后就能清偿，先去买点日常用品吧' : '账单正在清偿处理中，完成后可继续', style: const TextStyle(color: Colors.white60, fontSize: 11))),
                  ]),
                ),
              ]),
            ),
            const GuideStrip('clear', margin: EdgeInsets.fromLTRB(16, 0, 16, 0)),

            // 进行中
            if (active.isNotEmpty) ...[
              const SHeader('正在处理', sub: '银行会在每一步发来回执'),
              for (final c in active) _ClearanceCard(c, m: m),
            ],

            // 账单
            SHeader('待清偿账单', sub: open.isEmpty ? null : '剩余 ${fmtMoney(toD(bills['outstanding']))} · 已偿清 ${(toD(bills['progress']) * 100).toStringAsFixed(1)}%', action: '查询导入', onAction: () => _toBank(context, reload)),
            if (debts.isEmpty)
              SCard(
                onTap: () => _toBank(context, reload),
                child: Row(children: [
                  MallImage(mediaImg('bank_query'), width: 88, height: 66, radius: 12),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('还没有导入账单', style: Sx.h3),
                    SizedBox(height: 4),
                    Text('输入手机号，合作银行帮你一次查清', style: Sx.small),
                  ])),
                  const Icon(Icons.chevron_right_rounded, color: Sx.muted),
                ]),
              ),
            for (final d in debts) _BillCard(d, m: m),

            // 历史
            if (cls.any((c) => ![10, 20, 30].contains(toI(c['status'])))) ...[
              const SHeader('清偿记录'),
              for (final c in cls.where((c) => ![10, 20, 30].contains(toI(c['status'])))) _ClearanceCard(c, m: m),
            ],

            // 清偿金明细
            SHeader('清偿金明细', sub: '每一笔购物返还都在这里', action: '订单', onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MallOrdersPage()))),
            if ((cm['list'] as List).isEmpty) const SEmpty('还没有购物返还\n去商城买点本来就要买的东西吧'),
            for (final c in (cm['list'] as List).take(20))
              SCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(width: 38, height: 38, decoration: BoxDecoration(color: Sx.mintSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.shopping_bag_rounded, color: Sx.mint, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('购物返还 · 实付 ${fmtMoney(toD(c['pay_amount']))}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Sx.ink)),
                    Text('${c['order_no']}', style: Sx.small),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('+${fmtMoney(toD(c['dp_amount']))}', style: TextStyle(color: toI(c['status']) == 9 ? Sx.muted : Sx.mint, fontWeight: FontWeight.w900, decoration: toI(c['status']) == 9 ? TextDecoration.lineThrough : null)),
                    Text('${c['status_label']}', style: TextStyle(fontSize: 11, color: commissionColor(toI(c['status'])))),
                  ]),
                ]),
              ),
          ]);
        },
      )),
    );
  }

  Widget _stat(String k, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 2),
        Text(k, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
      ]));

  Widget _ghost(String t, VoidCallback onTap) => OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), minimumSize: const Size(0, 48), shape: const StadiumBorder()),
        onPressed: onTap,
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Future<void> _toBank(BuildContext context, VoidCallback reload) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const BankQueryPage()));
    reload();
  }

  void _explain(BuildContext context) => showXSheet(context, title: '什么是清偿金', ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [
        const Text('你在星光云买的每一件商品，平台都会获得一笔返佣。我们把这笔返佣按「返还倍率」换算成清偿金返还给你。', style: Sx.body),
        const SizedBox(height: 12),
        const Text('清偿金 = 平台返佣 × 返还倍率', style: Sx.h3),
        const SizedBox(height: 6),
        const Text('· 返还倍率由商品品类和你的信用分决定，信用越好倍率越高\n· 1 元清偿金可为你核减 1 元银行账单\n· 平台把返佣对应的资金划转给银行，其余部分是合作银行给你的让利\n· 确认收货后有 7 天售后保障期，期满自动到账；退款的订单不计入', style: Sx.body),
        const SizedBox(height: 16),
        SButton('看视频了解', icon: Icons.play_circle_fill_rounded, onTap: () {
          Navigator.pop(context);
          playGuide(context, 'credit');
        }),
      ]));

  Future<void> _clearSheet(BuildContext context, MallState m, List<dynamic> open, double avail, VoidCallback reload) async {
    final candidates = open.where((d) => d['clearing'] != true).toList();
    int caseId = toI(candidates.first['id']);
    double amount = avail;
    final ok = await showXSheet<bool>(context, title: '一键清偿', StatefulBuilder(builder: (ctx, setSt) {
      final d = candidates.firstWhere((x) => toI(x['id']) == caseId);
      final use = amount.clamp(0.0, toD(d['outstanding'])).toDouble();
      final settles = use >= toD(d['outstanding']) - 0.005;
      return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        const Text('选择要清偿的账单', style: Sx.h3),
        const SizedBox(height: 10),
        for (final x in candidates)
          GestureDetector(
            onTap: () => setSt(() => caseId = toI(x['id'])),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: toI(x['id']) == caseId ? Sx.ink : Sx.line, width: toI(x['id']) == caseId ? 1.6 : 1)),
              child: Row(children: [
                BankLogo(bankOf(m, x['bank_code'] as String?, x['creditor'] as String?), size: 34),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${x['creditor']}', style: Sx.h3),
                  Text('${x['debt_type']} · 尾号 ${(x['case_no'] as String).substring((x['case_no'] as String).length - 4)}', style: Sx.small),
                ])),
                Text(fmtMoney(toD(x['outstanding'])), style: const TextStyle(fontWeight: FontWeight.w800, color: Sx.ink)),
              ]),
            ),
          ),
        const SizedBox(height: 10),
        Row(children: [const Text('使用清偿金', style: Sx.h3), const Spacer(), Text(fmtMoney(use), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Sx.mint))]),
        Slider(value: amount.clamp(0, avail), min: 0, max: avail, activeColor: Sx.mint, onChanged: (v) => setSt(() => amount = (v * 100).roundToDouble() / 100)),
        Text(settles ? '这笔账单将被全部偿清，银行会出具《偿清证明》' : '清偿后剩余 ${fmtMoney(toD(d['outstanding']) - use)}', style: TextStyle(fontSize: 12, color: settles ? Sx.mint : Sx.muted, fontWeight: settles ? FontWeight.w800 : FontWeight.w500)),
        const SizedBox(height: 18),
        SButton('确认清偿 ${fmtMoney(use)}', onTap: use < 0.01 ? null : () => Navigator.pop(ctx, true)),
        const SizedBox(height: 8),
        const Text('提交后由银行受理 → 资金划转 → 核减账单，通常 1 个工作日内完成；受理前可被退回，清偿金会原路返还。', style: Sx.small, textAlign: TextAlign.center),
      ]);
    }));
    if (ok != true || !context.mounted) return;
    final d = candidates.firstWhere((x) => toI(x['id']) == caseId);
    final use = amount.clamp(0.0, toD(d['outstanding'])).toDouble();
    final r = await mallRun(context, () => m.submitClearance(caseId, use));
    if (r == null || !context.mounted) return;
    reload();
    await showDialog(context: context, builder: (dc) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: 180, width: double.infinity, child: MallImage(mediaImg('clear_success'), radius: 0, full: true, alignment: const Alignment(0, -0.4))),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            const Text('清偿已提交', style: Sx.h1),
            const SizedBox(height: 8),
            Text('${fmtMoney(toD(r['points']))} 正在发往 ${d['creditor']}', style: Sx.body, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('银行受理、资金划转、核减完成时，都会给你发回执', style: Sx.small, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            SButton('好的', onTap: () => Navigator.pop(dc)),
            TextButton(onPressed: () { Navigator.pop(dc); playGuide(context, 'progress'); }, child: const Text('看看接下来会发生什么', style: TextStyle(color: Sx.gold))),
          ]),
        ),
      ]),
    ));
  }
}

class _BillCard extends StatelessWidget {
  final Map d;
  final MallState m;
  const _BillCard(this.d, {required this.m});
  @override
  Widget build(BuildContext context) {
    final settled = toI(d['status']) == 3;
    final p = toD(d['principal']);
    final prog = p == 0 ? 0.0 : (toD(d['cleared']) / p).clamp(0.0, 1.0);
    final no = d['case_no'] as String;
    return SCard(
      onTap: settled ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificatesPage())) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          BankLogo(bankOf(m, d['bank_code'] as String?, d['creditor'] as String?), size: 38),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['creditor']}', style: Sx.h3),
            const SizedBox(height: 2),
            Text('${d['debt_type']} · 尾号 ${no.substring(no.length - 4)}', style: Sx.small),
          ])),
          if (settled) const SPill('已偿清', color: Sx.mint, icon: Icons.workspace_premium_rounded) else if (d['clearing'] == true) const SPill('清偿处理中', color: Sx.gold) else const SPill('待清偿', color: Sx.inkSoft),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(settled ? '已全部偿清' : '剩余待清偿', style: Sx.small),
            Text(fmtMoney(toD(d['outstanding'])), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: settled ? Sx.mint : Sx.ink)),
          ]),
          const Spacer(),
          Text('已清偿 ${fmtMoney(toD(d['cleared']))} / ${fmtMoney(p)}', style: Sx.small),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(minHeight: 6, value: prog, backgroundColor: Sx.line, color: Sx.mint)),
        if (settled) const Padding(padding: EdgeInsets.only(top: 10), child: Text('点击查看银行出具的《偿清证明》 ›', style: TextStyle(fontSize: 12, color: Sx.gold, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _ClearanceCard extends StatelessWidget {
  final Map c;
  final MallState m;
  const _ClearanceCard(this.c, {required this.m});
  @override
  Widget build(BuildContext context) {
    final st = toI(c['status']);
    final hist = (c['history'] as List).cast<Map>();
    const flow = [10, 20, 30, 50];
    const labels = ['已提交', '银行受理', '资金划转', '核减完成'];
    final idx = st == 90 ? -1 : flow.indexOf(st);
    return SCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${c['creditor']}', style: Sx.h3)),
          Text(fmtMoney(toD(c['points'])), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Sx.mint)),
        ]),
        const SizedBox(height: 2),
        Text('${c['clearance_no']} · ${fmtDate(DateTime.parse(c['created_at'] as String).toLocal())}', style: Sx.small),
        const SizedBox(height: 14),
        if (st == 90)
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFDEDEA), borderRadius: BorderRadius.circular(10)), child: Text('已退回：${c['reject_reason'] ?? ''}，清偿金已原路返还', style: const TextStyle(fontSize: 12, color: Sx.coral)))
        else
          Row(children: [
            for (var i = 0; i < flow.length; i++) ...[
              Column(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: i <= idx ? Sx.mint : Colors.white, shape: BoxShape.circle, border: Border.all(color: i <= idx ? Sx.mint : Sx.line, width: 2)),
                  child: i < idx || (i == idx && st == 50) ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : (i == idx ? const Padding(padding: EdgeInsets.all(5), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : null),
                ),
                const SizedBox(height: 4),
                Text(labels[i], style: TextStyle(fontSize: 10.5, color: i <= idx ? Sx.ink : Sx.muted, fontWeight: i == idx ? FontWeight.w800 : FontWeight.w500)),
              ]),
              if (i < flow.length - 1) Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 18), color: i < idx ? Sx.mint : Sx.line)),
            ],
          ]),
        if (hist.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Sx.bg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.receipt_rounded, size: 15, color: Sx.gold),
              const SizedBox(width: 6),
              Expanded(child: Text('${hist.last['note']}', style: const TextStyle(fontSize: 11.5, color: Sx.inkSoft))),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ───────────────────────── 银行账单查询 ─────────────────────────

class BankQueryPage extends StatefulWidget {
  const BankQueryPage({super.key});
  @override
  State<BankQueryPage> createState() => _BankQueryPageState();
}

class _BankQueryPageState extends State<BankQueryPage> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  bool _consent = true;
  int _cd = 0;
  bool _loading = false;
  int _phase = 0; // 0 输入 1 查询动画 2 结果
  Map<String, dynamic>? _res;
  final Set<int> _sel = {};
  Timer? _t;

  @override
  void initState() {
    super.initState();
    final m = context.read<MallState>();
    final ext = m.me?['ext_id'] as String?;
    // 演示身份预填其注册手机号
    if (ext != null) _mobile.text = '1380000${ext.substring(1)}';
  }

  @override
  void dispose() {
    _t?.cancel();
    _mobile.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final m = context.read<MallState>();
    final r = await mallRun(context, () => m.bankSms(_mobile.text.trim()));
    if (r == null || !mounted) return;
    mallToast(context, r['hint'] != null ? '验证码已发送（${r['hint']}）' : '验证码已发送');
    if (r['hint'] != null) _code.text = RegExp(r'\d{6}').firstMatch(r['hint'] as String)?.group(0) ?? '';
    setState(() => _cd = 60);
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _cd <= 1) {
        t.cancel();
        if (mounted) setState(() => _cd = 0);
        return;
      }
      setState(() => _cd--);
    });
  }

  Future<void> _query() async {
    if (!_consent) return mallToast(context, '请先阅读并同意授权书', ok: false);
    setState(() {
      _loading = true;
      _phase = 1;
    });
    final m = context.read<MallState>();
    final started = DateTime.now();
    final r = await mallRun(context, () => m.bankQuery(_mobile.text.trim(), _code.text.trim()));
    // 查询动画至少展示 2.4 秒，让用户感知「正在连接各家银行」
    final wait = const Duration(milliseconds: 2400) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future.delayed(wait);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _res = r;
      _phase = r == null ? 0 : 2;
      _sel
        ..clear()
        ..addAll(((r?['bills'] as List?) ?? const []).where((b) => b['imported'] != true).map((b) => toI(b['id'])));
    });
  }

  Future<void> _import() async {
    final m = context.read<MallState>();
    setState(() => _loading = true);
    final r = await mallRun(context, () => m.bankImport(_sel.toList()));
    if (!mounted) return;
    setState(() => _loading = false);
    if (r == null) return;
    await showDialog(context: context, builder: (dc) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: const Icon(Icons.mark_email_read_rounded, color: Sx.mint, size: 40),
      title: Text('${r['imported']} 笔账单已接入'),
      content: const Text('银行已发来《账单接入确认函》。之后购物返还的清偿金，都可以直接用来清偿这些账单。', textAlign: TextAlign.center),
      actions: [FilledButton(style: FilledButton.styleFrom(backgroundColor: Sx.ink), onPressed: () => Navigator.pop(dc), child: const Text('去清偿中心'))],
    ));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('查询银行账单'),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: switch (_phase) {
          1 => _scanning(m),
          2 => _result(m),
          _ => _form(m),
        },
      ),
    );
  }

  Widget _form(MallState m) => ListView(key: const ValueKey(0), padding: const EdgeInsets.only(bottom: 30), children: [
        SCard(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: EdgeInsets.zero,
          child: Column(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Sx.r)),
              child: SizedBox(height: 150, width: double.infinity, child: Stack(fit: StackFit.expand, children: [
                MallImage(mediaImg('bank_query'), radius: 0, full: true),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC121A33)]))),
                const Positioned(left: 18, bottom: 14, right: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('一次看清名下所有账单', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  SizedBox(height: 3),
                  Text('合作银行实时查询 · 仅本人授权可查', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
              ])),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                _field(_mobile, '手机号', Icons.phone_iphone_rounded, TextInputType.phone),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(_code, '短信验证码', Icons.sms_rounded, TextInputType.number)),
                  const SizedBox(width: 10),
                  SizedBox(width: 112, height: 50, child: OutlinedButton(style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: const BorderSide(color: Sx.line)), onPressed: _cd > 0 ? null : _send, child: Text(_cd > 0 ? '${_cd}s' : '获取验证码', maxLines: 1, softWrap: false, style: const TextStyle(color: Sx.ink, fontWeight: FontWeight.w700, fontSize: 13)))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Checkbox(value: _consent, activeColor: Sx.ink, shape: const CircleBorder(), onChanged: (v) => setState(() => _consent = v ?? false)),
                  Expanded(child: GestureDetector(onTap: _showConsent, child: const Text.rich(TextSpan(style: Sx.small, children: [TextSpan(text: '我已阅读并同意 '), TextSpan(text: '《银行账单查询授权书》', style: TextStyle(color: Sx.blue, fontWeight: FontWeight.w700))])))),
                ]),
                const SizedBox(height: 10),
                SButton('立即查询', icon: Icons.search_rounded, loading: _loading, onTap: _mobile.text.length == 11 && _code.text.length == 6 ? _query : null),
              ]),
            ),
          ]),
        ),
        const GuideStrip('bank', margin: EdgeInsets.fromLTRB(16, 0, 16, 0)),
        const SHeader('为什么可以放心'),
        _trust(Icons.lock_rounded, '仅本人授权查询', '短信验证 + 授权书，查询记录可追溯'),
        _trust(Icons.visibility_off_rounded, '只读不扣款', '查询不会影响你的账户，也不会主动扣款'),
        _trust(Icons.verified_user_rounded, '持牌合作机构', '与 12 家银行和持牌消费金融机构直连'),
      ]);

  Widget _field(TextEditingController c, String hint, IconData icon, TextInputType kt) => TextField(
        controller: c,
        keyboardType: kt,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
        decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: Sx.muted, size: 20), filled: true, fillColor: Sx.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 15)),
      );

  Widget _trust(IconData i, String t, String s) => SCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: Sx.blueSoft, borderRadius: BorderRadius.circular(12)), child: Icon(i, color: Sx.blue, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: Sx.h3), const SizedBox(height: 2), Text(s, style: Sx.small)])),
        ]),
      );

  void _showConsent() => showXSheet(context, title: '银行账单查询授权书', const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Text('本人授权星光云（以下简称“平台”）通过合作银行及持牌金融机构的开放接口，查询本人名下的信用卡、消费贷款及经营贷款账单信息（包括机构名称、账户尾号、待还金额、逾期状态），用于为本人提供清偿服务。\n\n1. 授权有效期为本次查询起 15 分钟；\n2. 平台不会获取本人的账户密码，不会主动发起扣款；\n3. 本人可随时在「我的 - 隐私与授权」中撤回授权；\n4. 查询记录将按监管要求留存并可追溯。', style: Sx.body),
      ));

  Widget _scanning(MallState m) {
    final banks = ((m.stats?['banks'] as List?) ?? const []).cast<Map>();
    return Center(
      key: const ValueKey(1),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 72, height: 72, child: CircularProgressIndicator(color: Sx.gold, strokeWidth: 4)),
          const SizedBox(height: 22),
          const Text('正在连接合作银行…', style: Sx.h2),
          const SizedBox(height: 6),
          const Text('通常需要几秒钟', style: Sx.small),
          const SizedBox(height: 24),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < banks.length; i++) TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 300 + i * 150), builder: (_, v, child) => Opacity(opacity: v, child: child), child: BankLogo(banks[i], size: 34)),
          ]),
        ]),
      ),
    );
  }

  Widget _result(MallState m) {
    final r = _res!;
    final bills = (r['bills'] as List).cast<Map>();
    final selAmt = bills.where((b) => _sel.contains(toI(b['id']))).fold(0.0, (a, b) => a + toD(b['amount']));
    return Column(key: const ValueKey(2), children: [
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 20), children: [
        SCard(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          gradient: Sx.heroGrad,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('手机号 ${r['mobile']} 名下', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            Text('共 ${bills.length} 笔账单，合计 ${fmtMoney(toD(r['total']))}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('查询编号 ${r['query_no']} · ${fmtDate(DateTime.parse(r['queried_at'] as String).toLocal())}', style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
          ]),
        ),
        for (final b in bills)
          SCard(
            onTap: b['imported'] == true ? null : () => setState(() => _sel.contains(toI(b['id'])) ? _sel.remove(toI(b['id'])) : _sel.add(toI(b['id']))),
            child: Row(children: [
              BankLogo(b['bank'] as Map?, size: 42),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b['bank_name']} · ${b['product']}', style: Sx.h3),
                const SizedBox(height: 3),
                Text('账户尾号 ${(b['account_no'] as String).substring((b['account_no'] as String).length - 4)}${toI(b['overdue_days']) > 0 ? ' · 已逾期 ${b['overdue_days']} 天' : ' · 状态正常'}', style: Sx.small),
                const SizedBox(height: 6),
                Text(fmtMoney(toD(b['amount'])), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Sx.ink)),
              ])),
              if (b['imported'] == true) const SPill('已接入', color: Sx.mint) else Checkbox(value: _sel.contains(toI(b['id'])), activeColor: Sx.ink, shape: const CircleBorder(), onChanged: (v) => setState(() => v == true ? _sel.add(toI(b['id'])) : _sel.remove(toI(b['id'])))),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text('接入后：购物返还的清偿金可直接清偿这些账单；银行会在每次清偿后发来回执，全部偿清时出具《偿清证明》。', style: Sx.small.copyWith(height: 1.6)),
        ),
        const GuideStrip('bank'),
        TextButton(onPressed: () => setState(() => _phase = 0), child: const Text('换个手机号查询', style: TextStyle(color: Sx.muted))),
      ])),
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(color: Colors.white, boxShadow: Sx.shadow(0.06)),
          child: SButton(_sel.isEmpty ? '已全部接入' : '接入 ${_sel.length} 笔账单（${fmtMoney(selAmt)}）', loading: _loading, onTap: _sel.isEmpty ? null : _import),
        ),
      ),
    ]);
  }
}

// ───────────────────────── 银行回函 ─────────────────────────

class LettersPage extends StatelessWidget {
  const LettersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('银行回函'),
      body: Loader<List<dynamic>>(
        load: m.letters,
        builder: (ctx, list, reload) => list.isEmpty
            ? ListView(children: const [SEmpty('还没有银行回函\n接入账单或完成清偿后，银行会在这里给你回信', img: 'empty_debt')])
            : ListView(padding: const EdgeInsets.only(top: 4, bottom: 24), children: [
                const GuideStrip('progress', margin: EdgeInsets.fromLTRB(16, 0, 16, 12)),
                for (final l in list)
                  SCard(
                    onTap: () async {
                      if (toI(l['read']) == 0) await m.readLetter(toI(l['id']));
                      if (ctx.mounted) await Navigator.push(ctx, MaterialPageRoute(builder: (_) => LetterDetailPage(l as Map)));
                      reload();
                    },
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(gradient: l['kind'] == 'settled' ? Sx.goldGrad : null, color: l['kind'] == 'settled' ? null : (l['kind'] == 'partial' ? Sx.mintSoft : Sx.blueSoft), borderRadius: BorderRadius.circular(14)),
                        child: Icon(l['kind'] == 'settled' ? Icons.workspace_premium_rounded : (l['kind'] == 'partial' ? Icons.receipt_long_rounded : Icons.mark_email_read_rounded), color: l['kind'] == 'settled' ? Colors.white : (l['kind'] == 'partial' ? Sx.mint : Sx.blue)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${l['title']}', style: Sx.h3)),
                          if (toI(l['read']) == 0) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Sx.coral, shape: BoxShape.circle)),
                        ]),
                        const SizedBox(height: 3),
                        Text('${l['bank_name']} · ${fmtDate(DateTime.parse(l['created_at'] as String).toLocal())}', style: Sx.small),
                        const SizedBox(height: 4),
                        Text('${l['body']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Sx.small.copyWith(color: Sx.inkSoft)),
                      ])),
                    ]),
                  ),
              ]),
      ),
    );
  }
}

class LetterDetailPage extends StatelessWidget {
  final Map l;
  const LetterDetailPage(this.l, {super.key});
  @override
  Widget build(BuildContext context) {
    final settled = l['kind'] == 'settled';
    return Scaffold(
      backgroundColor: const Color(0xFFEFEBE3),
      appBar: AppBar(backgroundColor: const Color(0xFFEFEBE3), foregroundColor: Sx.ink, elevation: 0, title: const Text('回函', style: TextStyle(fontWeight: FontWeight.w800, color: Sx.ink))),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: BoxDecoration(color: const Color(0xFFFFFDF8), borderRadius: BorderRadius.circular(6), boxShadow: Sx.shadow(0.1), border: Border.all(color: const Color(0xFFE8DCC4))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BankLogo(bankOf(context.read<MallState>(), null, l['bank_name'] as String?), size: 40),
              const SizedBox(width: 10),
              Expanded(child: Text('${l['bank_name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Sx.ink))),
            ]),
            const Divider(height: 32, color: Color(0xFFE8DCC4)),
            Center(child: Text('${l['title']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Sx.ink, letterSpacing: 2))),
            const SizedBox(height: 22),
            Text('${l['body']}', style: const TextStyle(fontSize: 14, height: 2, color: Sx.ink)),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerRight,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${l['bank_name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Sx.ink)),
                  const SizedBox(height: 4),
                  Text(fmtDay(DateTime.parse(l['created_at'] as String).toLocal()), style: Sx.small),
                ]),
                Positioned(right: 90, top: -26, child: Transform.rotate(angle: -0.25, child: Container(width: 76, height: 76, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xAAC8102E), width: 2.5)), alignment: Alignment.center, child: const Text('业务专用章', style: TextStyle(color: Color(0xAAC8102E), fontSize: 11, fontWeight: FontWeight.w900))))),
              ]),
            ),
            const SizedBox(height: 18),
            Text('回函编号：${l['ref_no']}', style: Sx.small),
          ]),
        ),
        if (settled) ...[
          const SizedBox(height: 18),
          SButton('查看《偿清证明》', gold: true, icon: Icons.workspace_premium_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CertificatesPage()))),
        ],
        const GuideStrip('cert', margin: EdgeInsets.only(top: 14)),
      ]),
    );
  }
}

// ───────────────────────── 偿清证明 ─────────────────────────

class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('偿清证明'),
      body: Loader<List<dynamic>>(
        load: m.certificates,
        builder: (ctx, list, reload) => ListView(padding: const EdgeInsets.only(top: 4, bottom: 24), children: [
          if (list.isEmpty) ...[
            SCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(Sx.r)), child: SizedBox(height: 170, width: double.infinity, child: MallImage(mediaImg('cert_letter'), radius: 0, full: true))),
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(children: [
                    Text('偿清后，银行会给你一份证明', style: Sx.h2),
                    SizedBox(height: 6),
                    Text('任意一笔账单余额归零，合作银行会出具电子《偿清证明》并发来偿清确认函，同步更新征信结清状态。', style: Sx.body, textAlign: TextAlign.center),
                  ]),
                ),
              ]),
            ),
            const GuideStrip('cert', margin: EdgeInsets.fromLTRB(16, 0, 16, 0)),
          ],
          for (final c in list) _CertView(c as Map),
          if (list.isNotEmpty) const GuideStrip('score', margin: EdgeInsets.fromLTRB(16, 4, 16, 0)),
        ]),
      ),
    );
  }
}

class _CertView extends StatelessWidget {
  final Map c;
  const _CertView(this.c);
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: Sx.shadow(0.12)),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned.fill(child: MallImage(mediaImg('cert_bg'), radius: 0, full: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 40, 34, 34),
          child: Column(children: [
            BankLogo(bankOf(m, null, c['bank_name'] as String?), size: 44),
            const SizedBox(height: 8),
            Text('${c['bank_name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Sx.ink)),
            const SizedBox(height: 18),
            const Text('偿 清 证 明', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF8A6A2F), letterSpacing: 6)),
            const SizedBox(height: 4),
            const Text('CERTIFICATE OF SETTLEMENT', style: TextStyle(fontSize: 9, color: Color(0xFFB0935A), letterSpacing: 3)),
            const SizedBox(height: 22),
            Text('兹证明客户 ${m.me?['nickname'] ?? ''}（手机 ${m.me?['mobile'] ?? ''}）在我行开立的账户（${c['case_no']}）原待清偿金额 ${fmtMoney(toD(c['principal']))}，已于 ${fmtDay(DateTime.parse(c['issued_at'] as String).toLocal())} 通过星光云清偿通道全部偿清，截至出具之日无剩余应还款项。\n\n特此证明。', style: const TextStyle(fontSize: 13, height: 1.9, color: Sx.ink)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('证明编号  ${c['cert_no']}', style: const TextStyle(fontSize: 10.5, color: Sx.inkSoft)),
                const SizedBox(height: 3),
                Text('电子签章  ${(c['signature'] as String).substring(0, 20)}…', style: const TextStyle(fontSize: 10.5, color: Sx.inkSoft)),
              ])),
              Transform.rotate(angle: -0.2, child: Container(width: 78, height: 78, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xCCC8102E), width: 2.5)), alignment: Alignment.center, child: const Text('偿清\n专用章', textAlign: TextAlign.center, style: TextStyle(color: Color(0xCCC8102E), fontSize: 12, fontWeight: FontWeight.w900, height: 1.2)))),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: 200, child: SButton('保存证明', primary: false, icon: Icons.download_rounded, onTap: () => mallToast(context, '已保存到相册（演示）'))),
          ]),
        ),
      ]),
    );
  }
}

// ───────────────────────── 信用分 ─────────────────────────

class CreditPage extends StatelessWidget {
  const CreditPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final score = toI(m.overview?['credit_score']);
    const tiers = [(550, 599, '+0', '起步'), (600, 649, '+0.5', '良好'), (650, 699, '+1.0', '优秀'), (700, 999, '+1.5', '卓越')];
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('信用分与返还倍率'),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        SCard(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: EdgeInsets.zero,
          child: Stack(children: [
            SizedBox(height: 190, width: double.infinity, child: ClipRRect(borderRadius: BorderRadius.circular(Sx.r), child: MallImage(mediaImg('score_up'), radius: 0, full: true))),
            Container(height: 190, decoration: BoxDecoration(borderRadius: BorderRadius.circular(Sx.r), gradient: const LinearGradient(colors: [Color(0xEE121A33), Color(0x33121A33)]))),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('我的信用分', style: TextStyle(color: Colors.white70)),
                Text('$score', style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 6),
                const Text('每次清偿 +3 · 偿清一笔账单 +15', style: TextStyle(color: Sx.gold, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        const GuideStrip('score', margin: EdgeInsets.fromLTRB(16, 0, 16, 0)),
        const SHeader('信用越好，返得越多', sub: '在品类基础倍率上额外加成'),
        for (final t in tiers)
          SCard(
            color: score >= t.$1 && score <= t.$2 ? Sx.goldSoft : null,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              SizedBox(width: 92, child: Text('${t.$1}${t.$2 >= 999 ? '+' : '~${t.$2}'}', style: Sx.h3)),
              Text(t.$4, style: Sx.body),
              const Spacer(),
              Text('倍率 ${t.$3}', style: const TextStyle(fontWeight: FontWeight.w900, color: Sx.gold)),
              if (score >= t.$1 && score <= t.$2) const Padding(padding: EdgeInsets.only(left: 8), child: SPill('当前', color: Sx.ink)),
            ]),
          ),
      ]),
    );
  }
}

// ───────────────────────── 指引中心 ─────────────────────────

class GuideCenterPage extends StatelessWidget {
  const GuideCenterPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final done = m.guides.where((g) => m.watchedGuides.contains(g.key)).length;
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('视频指引'),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        SCard(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('跟着视频，一步步轻松清偿', style: Sx.h3),
              const SizedBox(height: 4),
              Text('已看 $done / ${m.guides.length} 个', style: Sx.small),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 6, value: m.guides.isEmpty ? 0 : done / m.guides.length, color: Sx.gold, backgroundColor: Sx.line)),
            ])),
            const SizedBox(width: 16),
            SizedBox(width: 110, child: SButton('从头看', onTap: m.guides.isEmpty ? null : () => playGuide(context, m.guides.first.key))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth > 700 ? 4 : (c.maxWidth > 460 ? 3 : 2);
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('轻松清偿 · 主线', style: Sx.h2)),
              Wrap(spacing: 12, runSpacing: 12, children: [for (final g in m.guides.where((g) => g.group != 'labor')) GuideCard(g, width: w)]),
              const Padding(padding: EdgeInsets.only(top: 22, bottom: 10), child: Text('微劳动', style: Sx.h2)),
              Wrap(spacing: 12, runSpacing: 12, children: [for (final g in m.guides.where((g) => g.group == 'labor')) GuideCard(g, width: w)]),
            ]);
          }),
        ),
      ]),
    );
  }
}
