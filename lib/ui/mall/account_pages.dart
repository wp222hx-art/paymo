import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/mall_state.dart';
import '../widgets/common.dart';
import 'mall_order_pages.dart' show sAppBar;
import 'mall_widgets.dart';

// ───────────────────────── 钱包 / 收益 / 提现 ─────────────────────────

const _txIcon = {
  'task_income': (Icons.work_rounded, Sx.gold, '微劳动'),
  'content_income': (Icons.auto_stories_rounded, Sx.blue, '内容激励'),
  'withdraw': (Icons.north_east_rounded, Sx.inkSoft, '提现'),
  'withdraw_refund': (Icons.undo_rounded, Sx.coral, '提现退回'),
  'shop_pay': (Icons.shopping_bag_rounded, Sx.coral, '购物'),
  'shop_refund': (Icons.undo_rounded, Sx.mint, '退款'),
  'recharge': (Icons.add_card_rounded, Sx.mint, '充值'),
  'opening': (Icons.account_balance_wallet_rounded, Sx.muted, '期初'),
  'task_deposit': (Icons.lock_rounded, Sx.inkSoft, '任务押金'),
  'task_refund': (Icons.lock_open_rounded, Sx.mint, '押金退回'),
};

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _k = GlobalKey<LoaderState<Map<String, dynamic>>>();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('钱包 · 收益与提现'),
      body: Loader<Map<String, dynamic>>(
        key: _k,
        load: () async => Map<String, dynamic>.from(await m.get('/wallet2')),
        builder: (ctx, w, reload) {
          final kyc = w['kyc'] as Map;
          final inc = (w['income'] as Map?) ?? const {};
          return ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
            SCard(
              gradient: Sx.heroGrad,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('可提现余额', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                const SizedBox(height: 4),
                Text(fmtMoney(toD(w['balance'])), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(children: [
                  _s('微劳动收入', fmtMoney(toD(inc['labor']))),
                  _s('内容激励', fmtMoney(toD(inc['content']))),
                  _s('提现中', fmtMoney(toD(w['withdrawing']))),
                ]),
                const SizedBox(height: 16),
                SButton('提现到银行卡', gold: true, icon: Icons.north_east_rounded, onTap: () => _withdraw(m, w, reload)),
                const SizedBox(height: 8),
                Text(toI(kyc['level']) >= 4 ? '到账卡：${kyc['bank_name']} ${kyc['card_mask']}' : '提现前需要完成银行卡认证', style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            ),
            const GuideStrip('income', margin: EdgeInsets.fromLTRB(16, 0, 16, 0)),
            SCard(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycPage())).then((_) => reload()),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Sx.blueSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.verified_user_rounded, color: Sx.blue)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('实名与安全 · ${kyc['level_name']}', style: Sx.h3),
                  Text(kyc['has_pay_pwd'] == true ? '已设置支付密码' : '未设置支付密码', style: Sx.small),
                ])),
                const Icon(Icons.chevron_right_rounded, color: Sx.muted),
              ]),
            ),
            if ((w['withdrawals'] as List).isNotEmpty) ...[
              const SHeader('提现记录'),
              for (final x in w['withdrawals'] as List)
                SCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.account_balance_rounded, color: Sx.inkSoft),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('提现 ${fmtMoney(toD(x['amount']))}', style: Sx.h3),
                      Text('${x['bank_name']} ${x['card_mask']} · ${fmtDate(DateTime.parse(x['created_at'] as String).toLocal())}${x['reject_reason'] != null ? '\n${x['reject_reason']}' : ''}', style: Sx.small),
                    ])),
                    SPill('${x['status_label']}', color: switch (toI(x['status'])) { 30 => Sx.mint, 90 => Sx.coral, _ => Sx.gold }),
                  ]),
                ),
            ],
            const SHeader('收支明细'),
            for (final t in (w['txs'] as List))
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Sx.line))),
                child: Row(children: [
                  Icon((_txIcon[t['type']] ?? (Icons.receipt_rounded, Sx.muted, '')).$1, color: (_txIcon[t['type']] ?? (Icons.receipt_rounded, Sx.muted, '')).$2, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${t['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Sx.ink, fontWeight: FontWeight.w600)),
                    Text(fmtDate(DateTime.parse(t['created_at'] as String).toLocal()), style: Sx.small),
                  ])),
                  Text('${toD(t['amount']) > 0 ? '+' : ''}${fmtMoney(toD(t['amount']))}', style: TextStyle(fontWeight: FontWeight.w800, color: toD(t['amount']) > 0 ? Sx.mint : Sx.ink)),
                ]),
              ),
          ]);
        },
      ),
    );
  }

  Widget _s(String k, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        Text(k, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
      ]));

  Future<void> _withdraw(MallState m, Map w, VoidCallback reload) async {
    final kyc = w['kyc'] as Map;
    if (toI(kyc['level']) < 4 || kyc['has_pay_pwd'] != true) {
      mallToast(context, toI(kyc['level']) < 4 ? '请先完成银行卡认证' : '请先设置支付密码', ok: false);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const KycPage()));
      reload();
      return;
    }
    final amt = TextEditingController();
    final pwd = TextEditingController();
    final ok = await showXSheet<bool>(context, title: '提现到 ${kyc['bank_name']} ${kyc['card_mask']}', Builder(builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: amt, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900), decoration: InputDecoration(prefixText: '¥ ', hintText: '0.00', suffix: TextButton(onPressed: () => amt.text = toD(w['balance']).toStringAsFixed(2), child: const Text('全部')))),
        Text('可提现 ${fmtMoney(toD(w['balance']))} · 单笔 ≥ ¥10 · 500 元以内通常秒到', style: Sx.small),
        const SizedBox(height: 14),
        TextField(controller: pwd, obscureText: true, maxLength: 6, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '支付密码', counterText: '')),
        const SizedBox(height: 16),
        SButton('确认提现', onTap: () => Navigator.pop(ctx, true)),
      ]),
    )));
    if (ok != true || !mounted) return;
    final r = await mallRun(context, () async => Map<String, dynamic>.from(await m.post('/wallet2/withdraw', {'amount': double.tryParse(amt.text) ?? 0, 'pay_pwd': pwd.text})));
    if (r == null || !mounted) return;
    mallToast(context, toI(r['status']) == 30 ? '¥${toD(r['amount']).toStringAsFixed(2)} 已到账' : '提现申请已提交，正在审核');
    await m.refreshMe();
    reload();
  }
}

// ───────────────────────── 实名认证 ─────────────────────────

class KycPage extends StatefulWidget {
  const KycPage({super.key});
  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycPageState extends State<KycPage> {
  final _k = GlobalKey<LoaderState<Map<String, dynamic>>>();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('实名与安全'),
      body: Loader<Map<String, dynamic>>(
        key: _k,
        load: () async => Map<String, dynamic>.from(await m.get('/kyc')),
        builder: (ctx, k, reload) {
          final lv = toI(k['level']);
          return ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
            SCard(child: Row(children: [
              MallImage(mediaImg('kyc'), width: 72, height: 72, radius: 16),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('当前：${k['level_name']}', style: Sx.h2),
                const SizedBox(height: 4),
                Text(k['real_name'] != null ? '${k['real_name']} · ${k['id_no_mask']}' : '完成认证，解锁更多任务与提现', style: Sx.small),
              ])),
            ])),
            for (final l in (k['levels'] as List))
              SCard(
                padding: const EdgeInsets.all(14),
                onTap: l['done'] == true || toI(l['level']) == 1 || toI(l['level']) > lv + 1 ? null : () => _step(m, toI(l['level'])),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: l['done'] == true ? Sx.mint : (toI(l['level']) == lv + 1 ? Sx.ink : Sx.line), shape: BoxShape.circle),
                    child: l['done'] == true ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : Text('${l['level']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${l['name']}', style: Sx.h3),
                    Text('解锁：${l['unlock']}', style: Sx.small),
                  ])),
                  if (l['done'] == true) const SPill('已完成', color: Sx.mint) else if (toI(l['level']) == lv + 1) const SPill('去认证', color: Sx.ink) else const SPill('未解锁', color: Sx.muted),
                ]),
              ),
            SCard(
              padding: const EdgeInsets.all(14),
              onTap: () => _step(m, 99),
              child: Row(children: [
                const Icon(Icons.password_rounded, color: Sx.ink),
                const SizedBox(width: 12),
                const Expanded(child: Text('支付密码', style: Sx.h3)),
                Text(k['has_pay_pwd'] == true ? '已设置 · 修改' : '去设置', style: const TextStyle(color: Sx.gold, fontWeight: FontWeight.w700)),
              ]),
            ),
            const Padding(padding: EdgeInsets.all(20), child: Text('你的身份信息仅用于实名核验与资金安全，加密存储，不会用于其他用途。', style: Sx.small, textAlign: TextAlign.center)),
          ]);
        },
      ),
    );
  }

  Future<void> _step(MallState m, int level) async {
    final a = TextEditingController();
    final b = TextEditingController();
    final (title, step, fa, fb) = switch (level) {
      2 => ('实名认证', 'realname', '真实姓名', '身份证号'),
      3 => ('活体认证', 'liveness', '', ''),
      4 => ('绑定银行卡', 'bankcard', '开户银行（如 招商银行）', '银行卡号'),
      _ => ('设置支付密码', 'paypwd', '6 位数字支付密码', ''),
    };
    final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(
      title: Text(title),
      content: level == 3
          ? const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.face_retouching_natural_rounded, size: 64, color: Sx.gold), SizedBox(height: 10), Text('请正对屏幕，按提示眨眼、转头。\n（演示环境点击「开始」即模拟通过）', textAlign: TextAlign.center)])
          : Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: a, obscureText: level == 99, keyboardType: level == 99 ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: fa)),
              if (fb.isNotEmpty) TextField(controller: b, decoration: InputDecoration(labelText: fb)),
              if (level == 2) const Padding(padding: EdgeInsets.only(top: 8), child: Text('演示可用：张三 / 11010519491231002X', style: Sx.small)),
              if (level == 4) const Padding(padding: EdgeInsets.only(top: 8), child: Text('演示可用卡号：6225880112345674', style: Sx.small)),
            ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dc, true), child: Text(level == 3 ? '开始' : '提交'))],
    ));
    if (ok != true || !mounted) return;
    final body = switch (step) {
      'realname' => {'real_name': a.text.trim(), 'id_no': b.text.trim()},
      'bankcard' => {'bank_name': a.text.trim(), 'card_no': b.text.trim()},
      'paypwd' => {'pay_pwd': a.text.trim()},
      _ => <String, String>{},
    };
    final r = await mallRun(context, () => m.post('/kyc/$step', body), success: '$title完成');
    if (r != null) {
      await m.refreshMe();
      _k.currentState?.reload();
    }
  }
}

// ───────────────────────── 社区 ─────────────────────────

class CommunityPage2 extends StatefulWidget {
  const CommunityPage2({super.key});
  @override
  State<CommunityPage2> createState() => _CommunityPage2State();
}

class _CommunityPage2State extends State<CommunityPage2> {
  String _tab = 'hot';
  final _k = GlobalKey<LoaderState<List<dynamic>>>();
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('社区 · 轻松清偿故事', actions: [IconButton(tooltip: '我的内容', icon: const Icon(Icons.person_outline_rounded), onPressed: () => setState(() { _tab = 'mine'; _k.currentState?.reload(); }))]),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: Sx.ink, foregroundColor: Colors.white, onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const PostEditorPage())); _k.currentState?.reload(); }, icon: const Icon(Icons.edit_rounded), label: const Text('分享', style: TextStyle(fontWeight: FontWeight.w800))),
      body: Loader<List<dynamic>>(
        key: _k,
        load: () async => await m.get(_tab == 'mine' ? '/community/posts?mine=1' : '/community/posts?tab=$_tab') as List<dynamic>,
        builder: (ctx, list, reload) => ListView(padding: const EdgeInsets.only(bottom: 90), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(Sx.r), child: SizedBox(height: 120, child: Stack(fit: StackFit.expand, children: [
              MallImage(mediaImg('community_hero'), radius: 0, full: true),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xDD121A33), Color(0x22121A33)]))),
              const Padding(padding: EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('分享你的轻松清偿故事', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('优质内容获得激励：一份现金 + 一份清偿金', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              for (final t in const [('hot', '热门'), ('new', '最新'), ('mine', '我的')])
                Padding(padding: const EdgeInsets.only(right: 18), child: GestureDetector(onTap: () => setState(() { _tab = t.$1; reload(); }), child: Text(t.$2, style: TextStyle(fontSize: 15, fontWeight: _tab == t.$1 ? FontWeight.w900 : FontWeight.w500, color: _tab == t.$1 ? Sx.ink : Sx.muted)))),
            ]),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty) const SEmpty('还没有内容，来分享第一篇吧'),
          for (final p in list) _PostCard(p as Map, onChanged: reload),
        ]),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map p;
  final VoidCallback onChanged;
  const _PostCard(this.p, {required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    final st = toI(p['status']);
    return SCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(toI(p['id'])))).then((_) => onChanged()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: Sx.goldSoft, child: Text('${p['author'] ?? '?'}'.characters.first, style: const TextStyle(color: Sx.gold, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          Text('${p['author']}', style: Sx.h3),
          const SizedBox(width: 6),
          SPill('Lv.${p['author_level'] ?? 1}', color: Sx.gold),
          const Spacer(),
          if (st == 2) const SPill('精选', color: Sx.coral, icon: Icons.local_fire_department_rounded) else if (st != 1) SPill('${p['status_label']}', color: st == 9 ? Sx.coral : Sx.gold),
        ]),
        const SizedBox(height: 10),
        Text('${p['title']}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Sx.ink, height: 1.35)),
        const SizedBox(height: 6),
        Text('${p['body']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: Sx.body),
        if (st == 9 && p['block_reason'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('未通过：${p['block_reason']}', style: const TextStyle(fontSize: 12, color: Sx.coral))),
        const SizedBox(height: 10),
        Row(children: [
          for (final t in (p['tags'] as List? ?? const []).take(3)) Padding(padding: const EdgeInsets.only(right: 6), child: SPill('#$t', color: Sx.blue)),
          const Spacer(),
          InkWell(
            onTap: st == 1 || st == 2 ? () async { await mallRun(context, () => m.post('/community/posts/${p['id']}/like')); onChanged(); } : null,
            child: Padding(padding: const EdgeInsets.all(4), child: Row(children: [Icon(p['liked'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: p['liked'] == true ? Sx.coral : Sx.muted), const SizedBox(width: 3), Text('${p['likes']}', style: Sx.small)])),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Sx.muted),
          const SizedBox(width: 3),
          Text('${p['comments']}', style: Sx.small),
        ]),
      ]),
    );
  }
}

class PostDetailPage extends StatefulWidget {
  final int id;
  const PostDetailPage(this.id, {super.key});
  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _k = GlobalKey<LoaderState<Map<String, dynamic>>>();
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('正文'),
      body: Loader<Map<String, dynamic>>(
        key: _k,
        load: () async => Map<String, dynamic>.from(await m.get('/community/posts/${widget.id}')),
        builder: (ctx, p, reload) => ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['title']}', style: Sx.h1),
            const SizedBox(height: 8),
            Text('${p['author']} · ${fmtDate(DateTime.parse(p['created_at'] as String).toLocal())} · ${p['views']} 阅读', style: Sx.small),
            const SizedBox(height: 14),
            Text('${p['body']}', style: const TextStyle(fontSize: 14.5, height: 1.85, color: Sx.ink)),
            const SizedBox(height: 14),
            Row(children: [
              OutlinedButton.icon(style: OutlinedButton.styleFrom(shape: const StadiumBorder()), onPressed: () async { await mallRun(context, () => m.post('/community/posts/${p['id']}/like')); reload(); }, icon: Icon(p['liked'] == true ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Sx.coral), label: Text('${p['likes']}')),
            ]),
          ])),
          SCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('评论 ${p['comments']}', style: Sx.h3),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _c, decoration: InputDecoration(hintText: '友善发言，温暖彼此', isDense: true, filled: true, fillColor: Sx.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
              IconButton(icon: const Icon(Icons.send_rounded, color: Sx.ink), onPressed: () async {
                if (_c.text.trim().isEmpty) return;
                final r = await mallRun(context, () => m.post('/community/posts/${p['id']}/comments', {'body': _c.text.trim()}));
                if (r != null) { _c.clear(); reload(); }
              }),
            ]),
            for (final c in (p['comment_list'] as List? ?? const []))
              Padding(padding: const EdgeInsets.only(top: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 13, backgroundColor: Sx.bg, child: Text('${c['nickname']}'.characters.first, style: const TextStyle(fontSize: 11, color: Sx.ink))),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${c['nickname']}', style: Sx.small), Text('${c['body']}', style: const TextStyle(fontSize: 13, color: Sx.ink))])),
              ])),
          ])),
        ]),
      ),
    );
  }
}

class PostEditorPage extends StatefulWidget {
  const PostEditorPage({super.key});
  @override
  State<PostEditorPage> createState() => _PostEditorPageState();
}

class _PostEditorPageState extends State<PostEditorPage> {
  final _t = TextEditingController();
  final _b = TextEditingController();
  final Set<String> _tags = {};
  bool _busy = false;
  static const tags = ['真实经历', '偿清', '微劳动', '新手攻略', '日常消费', '探店', '清偿金'];
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('分享', actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: SizedBox(width: 84, child: SButton('发布', loading: _busy, onTap: () async {
          setState(() => _busy = true);
          final r = await mallRun(context, () async => Map<String, dynamic>.from(await m.post('/community/posts', {'title': _t.text.trim(), 'body': _b.text.trim(), 'tags': _tags.toList()})));
          if (!mounted) return;
          setState(() => _busy = false);
          if (r == null || !context.mounted) return;
          mallToast(context, switch (toI(r['status'])) { 1 => '已发布', 0 => '已提交，审核通过后发布', _ => '内容未通过：${r['block_reason'] ?? ''}' }, ok: toI(r['status']) != 9);
          Navigator.pop(context);
        }))),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _t, maxLength: 60, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), decoration: const InputDecoration(hintText: '标题', border: InputBorder.none)),
        TextField(controller: _b, maxLines: 14, maxLength: 5000, decoration: const InputDecoration(hintText: '分享你的经历和方法……\n\n请勿留联系方式、勿发布征信修复等违规信息', border: InputBorder.none)),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final t in tags) FilterChip(label: Text('#$t'), selected: _tags.contains(t), onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t)))]),
        const SizedBox(height: 12),
        const Text('发布需完成实名认证。内容会经过 AI 审核，违规内容不会发布。', style: Sx.small),
      ]),
    );
  }
}

// ───────────────────────── AI 助手 ─────────────────────────

class AiHubPage extends StatelessWidget {
  const AiHubPage({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('AI 助手'),
      body: Loader<List<dynamic>>(
        load: () async => await m.get('/ai/agents') as List<dynamic>,
        builder: (ctx, list, _) => ListView(padding: const EdgeInsets.only(top: 4, bottom: 30), children: [
          SCard(child: Row(children: [
            MallImage(mediaImg('ai_assistant'), width: 70, height: 70, radius: 35),
            const SizedBox(width: 14),
            const Expanded(child: Text('有什么不确定的，都可以问我。\n我会结合你的账单、清偿金和可接任务来回答。', style: Sx.body)),
          ])),
          for (final a in list)
            SCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiChatPage(a as Map))),
              child: Row(children: [
                Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: Sx.goldSoft, borderRadius: BorderRadius.circular(16)), child: Text('${a['icon']}', style: const TextStyle(fontSize: 24))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${a['name']}', style: Sx.h3), const SizedBox(height: 2), Text('${a['intro']}', style: Sx.small)])),
                const Icon(Icons.chevron_right_rounded, color: Sx.muted),
              ]),
            ),
        ]),
      ),
    );
  }
}

class AiChatPage extends StatefulWidget {
  final Map agent;
  const AiChatPage(this.agent, {super.key});
  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final List<Map> _msgs = [];
  final _c = TextEditingController();
  final _sc = ScrollController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<MallState>().get('/ai/${widget.agent['key']}/messages').then((v) {
      if (mounted) setState(() => _msgs.addAll((v as List).cast<Map>()));
      _down();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _sc.dispose();
    super.dispose();
  }

  void _down() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _send(String q) async {
    if (q.trim().isEmpty || _busy) return;
    final m = context.read<MallState>();
    setState(() {
      _msgs.add({'role': 'user', 'content': q.trim()});
      _busy = true;
    });
    _c.clear();
    _down();
    final r = await mallRun(context, () async => Map<String, dynamic>.from(await m.post('/ai/${widget.agent['key']}/chat', {'message': q.trim()})));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) _msgs.add({'role': 'assistant', 'content': r['reply']});
    });
    _down();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.agent;
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('${a['icon']} ${a['name']}', actions: [
        IconButton(tooltip: '清空', icon: const Icon(Icons.delete_sweep_outlined), onPressed: () async { await context.read<MallState>().del('/ai/${a['key']}/messages'); setState(_msgs.clear); }),
      ]),
      body: Column(children: [
        Expanded(child: ListView(controller: _sc, padding: const EdgeInsets.all(16), children: [
          if (_msgs.isEmpty) ...[
            Text('${a['intro']}，试试问我：', style: Sx.body),
            const SizedBox(height: 10),
            for (final p in (a['prompts'] as List)) Padding(padding: const EdgeInsets.only(bottom: 8), child: ActionChip(backgroundColor: Colors.white, side: BorderSide.none, shape: const StadiumBorder(), label: Text('$p'), onPressed: () => _send('$p'))),
          ],
          for (final x in _msgs)
            Align(
              alignment: x['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                decoration: BoxDecoration(color: x['role'] == 'user' ? Sx.ink : Colors.white, borderRadius: BorderRadius.circular(16)),
                child: SelectableText('${x['content']}', style: TextStyle(color: x['role'] == 'user' ? Colors.white : Sx.ink, fontSize: 14, height: 1.55)),
              ),
            ),
          if (_busy) const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Sx.gold)))),
        ])),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            color: Colors.white,
            child: Row(children: [
              Expanded(child: TextField(controller: _c, onSubmitted: _send, textInputAction: TextInputAction.send, decoration: InputDecoration(hintText: '问点什么…', isDense: true, filled: true, fillColor: Sx.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)))),
              IconButton(icon: const Icon(Icons.send_rounded, color: Sx.ink), onPressed: () => _send(_c.text)),
            ]),
          ),
        ),
      ]),
    );
  }
}
