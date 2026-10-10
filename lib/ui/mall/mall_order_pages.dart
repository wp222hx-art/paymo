import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/mall_state.dart';
import '../widgets/common.dart';
import 'clear_pages.dart';
import 'mall_widgets.dart';

export 'clear_pages.dart' show ClearCenterPage;

/// 兼容旧入口：「佣金 · 债务清算」→ 清偿中心
class CommissionCenterPage extends StatelessWidget {
  const CommissionCenterPage({super.key});
  @override
  Widget build(BuildContext context) => const ClearCenterPage();
}

AppBar sAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(backgroundColor: Sx.bg, foregroundColor: Sx.ink, elevation: 0, scrolledUnderElevation: 0, title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Sx.ink)), actions: actions, bottom: bottom);

// ───────────────────────── 确认订单 ─────────────────────────

class CheckoutPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final bool fromCart;
  const CheckoutPage({super.key, required this.items, this.fromCart = false});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Map<String, dynamic>? _pv;
  List<dynamic> _addrs = [];
  int? _addrId;
  final _remark = TextEditingController();
  bool _submitting = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final m = context.read<MallState>();
    try {
      final r = await Future.wait([m.preview(widget.items), m.addresses()]);
      if (!mounted) return;
      setState(() {
        _pv = r[0] as Map<String, dynamic>;
        _addrs = r[1] as List<dynamic>;
        _addrId ??= _addrs.isEmpty ? null : toI(_addrs.first['id']);
      });
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pv = _pv;
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('确认订单'),
      body: _err != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_err!, style: const TextStyle(color: Sx.coral))))
          : pv == null
              ? const Center(child: CircularProgressIndicator(color: Sx.gold))
              : ListView(padding: const EdgeInsets.only(top: 4, bottom: 20), children: [
                  _addrCard(),
                  SCard(child: Column(children: [
                    for (final it in pv['items'] as List<dynamic>)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          MallImage(it['image'] as String?, emoji: it['emoji'] as String? ?? '🛍️', width: 64, height: 64, radius: 12),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(it['name'] as String, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Sx.ink)),
                            const SizedBox(height: 4),
                            Text('${fmtMoney(toD(it['price']))} × ${it['qty']}', style: Sx.small),
                            const SizedBox(height: 4),
                            ReturnBadge(toD(it['dp_amount']), small: true),
                          ])),
                          Text(fmtMoney(toD(it['subtotal'])), style: const TextStyle(fontWeight: FontWeight.w800, color: Sx.ink)),
                        ]),
                      ),
                    const Divider(color: Sx.line, height: 18),
                    _kv('商品金额', fmtMoney(toD(pv['goods_amount']))),
                    _kv('运费', toD(pv['freight_amount']) == 0 ? '包邮' : '${fmtMoney(toD(pv['freight_amount']))}（满 ${toD(pv['free_freight_threshold']).toStringAsFixed(0)} 元包邮）'),
                    _kv('实付', fmtMoney(toD(pv['pay_amount'])), bold: true),
                  ])),
                  SCard(
                    gradient: Sx.mintGrad,
                    child: Row(children: [
                      const Icon(Icons.eco_rounded, color: Colors.white, size: 30),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('这一单可返 ${fmtMoney(toD(pv['dp_amount']))} 清偿金', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 3),
                        const Text('确认收货后进入 7 天售后保障期，期满自动到账，可直接用来清偿银行账单', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.45)),
                      ])),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(controller: _remark, maxLength: 200, decoration: InputDecoration(hintText: '给商家留言（选填）', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), isDense: true)),
                  ),
                  const GuideStrip('pay', margin: EdgeInsets.fromLTRB(16, 4, 16, 0)),
                ]),
      bottomNavigationBar: pv == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
                decoration: BoxDecoration(color: Colors.white, boxShadow: Sx.shadow(0.06)),
                child: Row(children: [
                  const Text('实付 ', style: TextStyle(color: Sx.ink, fontWeight: FontWeight.w700)),
                  PriceText(toD(pv['pay_amount']), size: 21),
                  const Spacer(),
                  SizedBox(width: 140, child: SButton('提交订单', loading: _submitting, onTap: _submit)),
                ]),
              ),
            ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Text(k, style: Sx.body), const Spacer(), Text(v, style: TextStyle(color: Sx.ink, fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 15 : 13))]),
      );

  Widget _addrCard() {
    final a = _addrs.where((x) => toI(x['id']) == _addrId).firstOrNull;
    return SCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      onTap: _pickAddr,
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Sx.goldSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.location_on_rounded, color: Sx.gold)),
        const SizedBox(width: 12),
        Expanded(
          child: a == null
              ? const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('添加收货地址', style: Sx.h3), Text('电子券 / 到店核销类商品可不填', style: Sx.small)])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${a['name']}  ${a['phone']}', style: Sx.h3),
                  const SizedBox(height: 2),
                  Text('${a['region']} ${a['detail']}', style: Sx.small),
                ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Sx.muted),
      ]),
    );
  }

  Future<void> _pickAddr() async {
    final m = context.read<MallState>();
    final picked = await showXSheet<int>(context, title: '选择收货地址', Builder(builder: (ctx) => RadioGroup<int>(
      groupValue: _addrId,
      onChanged: (v) => Navigator.pop(ctx, v),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        for (final a in _addrs)
          RadioListTile<int>(value: toI(a['id']), activeColor: Sx.ink, title: Text('${a['name']}  ${a['phone']}'), subtitle: Text('${a['region']} ${a['detail']}')),
        const SizedBox(height: 8),
        SButton('新增地址', primary: false, icon: Icons.add_rounded, onTap: () async {
          final created = await _newAddr(ctx);
          if (created != null && ctx.mounted) Navigator.pop(ctx, toI(created['id']));
        }),
        const SizedBox(height: 16),
      ]),
    )));
    if (picked != null) {
      final list = await m.addresses();
      if (!mounted) return;
      setState(() {
        _addrs = list;
        _addrId = picked;
      });
    }
  }

  Future<Map<String, dynamic>?> _newAddr(BuildContext ctx) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final region = TextEditingController();
    final detail = TextEditingController();
    final m = context.read<MallState>();
    return showDialog<Map<String, dynamic>>(context: ctx, builder: (dc) => AlertDialog(
      title: const Text('新增收货地址'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: '收货人')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '手机号')),
        TextField(controller: region, decoration: const InputDecoration(labelText: '省市区')),
        TextField(controller: detail, decoration: const InputDecoration(labelText: '详细地址')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dc), child: const Text('取消')),
        FilledButton(onPressed: () async {
          final r = await mallRun(dc, () => m.addAddress({'name': name.text, 'phone': phone.text, 'region': region.text, 'detail': detail.text}));
          if (r != null && dc.mounted) Navigator.pop(dc, r);
        }, child: const Text('保存')),
      ],
    ));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final m = context.read<MallState>();
    final o = await mallRun(context, () => m.createOrder(widget.items, addressId: _addrId, remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(), fromCart: widget.fromCart));
    if (!mounted) return;
    setState(() => _submitting = false);
    if (o == null) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CashierPage(o)));
  }
}

// ───────────────────────── 收银台 ─────────────────────────

class CashierPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const CashierPage(this.order, {super.key});
  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  String _channel = 'wallet';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    final o = widget.order;
    final amount = toD(o['pay_amount']);
    final balance = toD(m.me?['wallet_balance']);
    final top = ((amount - balance) / 100).ceil() * 100.0;
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('收银台'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SizedBox(height: 10),
        Center(child: Column(children: [
          const Text('需支付', style: Sx.body),
          const SizedBox(height: 4),
          PriceText(amount, size: 38),
          const SizedBox(height: 6),
          Text('订单 ${o['order_no']} · 30 分钟内有效', style: Sx.small),
          const SizedBox(height: 10),
          ReturnBadge(toD(o['dp_amount'])),
        ])),
        const SizedBox(height: 24),
        SCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: RadioGroup<String>(
            groupValue: _channel,
            onChanged: (v) => setState(() => _channel = v!),
            child: Column(children: [
              RadioListTile(value: 'wallet', activeColor: Sx.ink, secondary: const Icon(Icons.account_balance_wallet_rounded, color: Sx.gold), title: const Text('星光钱包', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('余额 ${fmtMoney(balance)}${balance < amount ? ' · 不足' : ''}', style: TextStyle(color: balance < amount ? Sx.coral : Sx.muted))),
              const RadioListTile(value: 'wechat', activeColor: Sx.ink, secondary: Icon(Icons.chat_bubble_rounded, color: Color(0xFF07C160)), title: Text('微信支付', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('演示环境 · 模拟收银台')),
              const RadioListTile(value: 'alipay', activeColor: Sx.ink, secondary: Icon(Icons.payments_rounded, color: Color(0xFF1677FF)), title: Text('支付宝', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('演示环境 · 模拟收银台')),
            ]),
          ),
        ),
        if (_channel == 'wallet' && balance < amount)
          Padding(padding: const EdgeInsets.only(top: 8), child: TextButton.icon(onPressed: () => mallRun(context, () => m.recharge(top), success: '充值成功（模拟）'), icon: const Icon(Icons.add_card_rounded, color: Sx.gold), label: Text('模拟充值 ${fmtMoney(top)}', style: const TextStyle(color: Sx.ink)))),
        const SizedBox(height: 24),
        SButton('确认支付 ${fmtMoney(amount)}', loading: _busy, onTap: () => _pay(m)),
        const GuideStrip('pay', margin: EdgeInsets.only(top: 18)),
      ]),
    );
  }

  Future<void> _pay(MallState m) async {
    setState(() => _busy = true);
    final r = await mallRun(context, () => m.pay(toI(widget.order['id']), _channel));
    if (r != null && r['paid'] != true && mounted) {
      final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(
        title: Text(_channel == 'wechat' ? '微信支付（模拟）' : '支付宝（模拟）'),
        content: Text('支付金额 ${fmtMoney(toD(r['amount']))}\n\n真实环境此处会拉起第三方支付，支付结果由异步通知回调到服务端。'),
        actions: [TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('模拟支付成功'))],
      ));
      if (ok != true || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final confirmed = await mallRun(context, () async {
        await m.mockConfirmPay(r['pay_no'] as String);
        return true;
      });
      if (confirmed != true) {
        if (mounted) setState(() => _busy = false);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PaySuccessPage(widget.order)));
  }
}

class PaySuccessPage extends StatelessWidget {
  final Map<String, dynamic> order;
  const PaySuccessPage(this.order, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Sx.bg,
        appBar: sAppBar('支付成功'),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 20),
          Center(child: Container(width: 76, height: 76, decoration: const BoxDecoration(gradient: Sx.mintGrad, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 44))),
          const SizedBox(height: 16),
          const Center(child: Text('支付成功', style: Sx.h1)),
          const SizedBox(height: 8),
          Center(child: Text('已为你预留 ${fmtMoney(toD(order['dp_amount']))} 清偿金', style: const TextStyle(color: Sx.mint, fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(height: 6),
          const Center(child: Text('收到商品后记得「确认收货」，7 天保障期满自动到账', style: Sx.small)),
          const SizedBox(height: 26),
          _flow(),
          const SizedBox(height: 26),
          Row(children: [
            Expanded(child: SButton('继续逛', primary: false, onTap: () => Navigator.popUntil(context, (r) => r.isFirst))),
            const SizedBox(width: 10),
            Expanded(child: SButton('查看订单', onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MallOrderDetailPage(toI(order['id'])))))),
          ]),
          const GuideStrip('receive', margin: EdgeInsets.only(top: 20)),
        ]),
      );

  Widget _flow() => SCard(
        margin: EdgeInsets.zero,
        child: Row(children: [
          for (final (i, t) in const ['已支付', '确认收货', '保障期', '到账', '清偿'].indexed) ...[
            Expanded(child: Column(children: [
              Icon(i == 0 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: i == 0 ? Sx.mint : Sx.line, size: 22),
              const SizedBox(height: 4),
              Text(t, style: TextStyle(fontSize: 11, color: i == 0 ? Sx.ink : Sx.muted, fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500)),
            ])),
          ],
        ]),
      );
}

// ───────────────────────── 订单列表 / 详情 ─────────────────────────

class MallOrdersPage extends StatelessWidget {
  final int initialIndex;
  const MallOrdersPage({super.key, this.initialIndex = 0});
  static const _tabs = [(null, '全部'), (10, '待支付'), (20, '待发货'), (30, '待收货'), (40, '已完成'), (60, '售后')];
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: Sx.bg,
        appBar: sAppBar('我的订单', bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelColor: Sx.ink, unselectedLabelColor: Sx.muted, indicatorColor: Sx.gold, indicatorSize: TabBarIndicatorSize.label, dividerColor: Colors.transparent, labelStyle: const TextStyle(fontWeight: FontWeight.w800), tabs: [for (final t in _tabs) Tab(text: t.$2)])),
        body: TabBarView(children: [for (final t in _tabs) _OrderList(t.$1)]),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final int? status;
  const _OrderList(this.status);
  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Loader<List<dynamic>>(
      load: () => m.orders(status: status),
      builder: (ctx, list, reload) => list.isEmpty
          ? ListView(children: const [SEmpty('还没有相关订单')])
          : ListView(padding: const EdgeInsets.only(top: 10, bottom: 20), children: [
              for (final o in list)
                SCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () async {
                    await Navigator.push(ctx, MaterialPageRoute(builder: (_) => MallOrderDetailPage(toI(o['id']))));
                    reload();
                  },
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(fmtDate(DateTime.parse(o['created_at'] as String).toLocal()), style: Sx.small),
                      const Spacer(),
                      Text('${o['status_label']}', style: TextStyle(color: orderColor(toI(o['status'])), fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 56,
                      child: Row(children: [
                        Expanded(child: ListView(scrollDirection: Axis.horizontal, children: [
                          for (final it in o['items'] as List<dynamic>) Padding(padding: const EdgeInsets.only(right: 8), child: MallImage(it['image'] as String?, emoji: it['emoji'] as String? ?? '🛍️', width: 56, height: 56, radius: 10)),
                        ])),
                        if ((o['items'] as List).length == 1) Expanded(flex: 2, child: Text('${(o['items'] as List).first['name']}', maxLines: 2, style: const TextStyle(fontSize: 13, color: Sx.ink))),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      SPill('清偿金 ${fmtMoney(toD(o['dp_amount']))} · ${o['commission_status_label']}', color: commissionColor(o['commission_status'] as int?)),
                      const Spacer(),
                      const Text('实付 ', style: Sx.small),
                      Text(fmtMoney(toD(o['pay_amount'])), style: const TextStyle(fontWeight: FontWeight.w900, color: Sx.ink)),
                    ]),
                  ]),
                ),
            ]),
    );
  }
}

class MallOrderDetailPage extends StatefulWidget {
  final int id;
  const MallOrderDetailPage(this.id, {super.key});
  @override
  State<MallOrderDetailPage> createState() => _MallOrderDetailPageState();
}

class _MallOrderDetailPageState extends State<MallOrderDetailPage> {
  final _k = GlobalKey<LoaderState<Map<String, dynamic>>>();

  @override
  Widget build(BuildContext context) {
    final m = context.read<MallState>();
    return Scaffold(
      backgroundColor: Sx.bg,
      appBar: sAppBar('订单详情'),
      body: Loader<Map<String, dynamic>>(
        key: _k,
        load: () => m.order(widget.id),
        builder: (ctx, o, reload) {
          final st = toI(o['status']);
          final cst = o['commission_status'] as int?;
          final addr = o['address'] as Map<String, dynamic>?;
          return ListView(padding: const EdgeInsets.only(top: 4, bottom: 24), children: [
            SCard(
              gradient: Sx.heroGrad,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['status_label']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_hint(st, cst, o), style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.45)),
                const SizedBox(height: 16),
                _flow(st, cst),
              ]),
            ),
            GuideStrip(st == 30 ? 'receive' : (cst == 2 ? 'clear' : (cst == 1 ? 'credit' : 'pay')), margin: const EdgeInsets.fromLTRB(16, 0, 16, 12)),
            if (addr != null)
              SCard(child: Row(children: [
                const Icon(Icons.location_on_rounded, color: Sx.gold),
                const SizedBox(width: 10),
                Expanded(child: Text('${addr['name']} ${addr['phone']}\n${addr['region']} ${addr['detail']}', style: const TextStyle(fontSize: 13, color: Sx.ink, height: 1.5))),
              ])),
            if (o['express_company'] != null)
              SCard(child: Row(children: [const Icon(Icons.local_shipping_rounded, color: Sx.blue), const SizedBox(width: 10), Text('${o['express_company']} ${o['express_no']}', style: Sx.h3)])),
            SCard(child: Column(children: [
              for (final it in o['items'] as List<dynamic>)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    MallImage(it['image'] as String?, emoji: it['emoji'] as String? ?? '🛍️', width: 58, height: 58, radius: 10),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${it['name']}', maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Sx.ink)),
                      const SizedBox(height: 3),
                      Text('${fmtMoney(toD(it['price']))} × ${it['qty']}', style: Sx.small),
                    ])),
                    ReturnBadge(toD(it['dp_amount']), small: true),
                  ]),
                ),
              const Divider(color: Sx.line),
              _kv('订单号', '${o['order_no']}'),
              _kv('下单时间', fmtDate(DateTime.parse(o['created_at'] as String).toLocal())),
              _kv('商品金额', fmtMoney(toD(o['goods_amount']))),
              _kv('运费', fmtMoney(toD(o['freight_amount']))),
              _kv('支付方式', switch (o['pay_channel']) { 'wallet' => '星光钱包', 'wechat' => '微信支付', 'alipay' => '支付宝', _ => '-' }),
              _kv('实付', fmtMoney(toD(o['pay_amount'])), bold: true),
              _kv('清偿金', '${fmtMoney(toD(o['dp_amount']))} · ${o['commission_status_label']}', color: Sx.mint, bold: true),
              if (o['refund_reject_reason'] != null) _kv('退款驳回', '${o['refund_reject_reason']}', color: Sx.coral),
            ])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: [
                if (st == 10) SizedBox(width: 120, child: SButton('取消订单', primary: false, onTap: () => _act(m, 'cancel', '订单已取消'))),
                if (st == 10) SizedBox(width: 120, child: SButton('去支付', onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => CashierPage(o))); _k.currentState?.reload(); })),
                if (st == 30) SizedBox(width: 140, child: SButton('确认收货', onTap: () => _act(m, 'confirm', '已确认收货，清偿金进入保障期'))),
                if ([20, 30, 40].contains(st) && cst != 2) SizedBox(width: 120, child: SButton('申请退款', primary: false, onTap: () => _refund(m))),
                if (cst == 2) SizedBox(width: 140, child: SButton('去清偿', gold: true, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClearCenterPage())))),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [SizedBox(width: 80, child: Text(k, style: Sx.small)), Expanded(child: Text(v, textAlign: TextAlign.right, style: TextStyle(color: color ?? Sx.ink, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: 13)))]),
      );

  String _hint(int st, int? cst, Map<String, dynamic> o) {
    if (st == 10) return '请在 30 分钟内完成支付';
    if (st == 20) return '商家正在备货，已为你预留清偿金 ${fmtMoney(toD(o['dp_amount']))}';
    if (st == 30) return '商品已发出，收到后点「确认收货」，清偿金开始计时到账';
    if (st == 40 && cst == 1) return '售后保障期中，${o['commission_settle_at'] != null ? '${fmtDate(DateTime.parse(o['commission_settle_at'] as String).toLocal())} ' : ''}自动到账 ${fmtMoney(toD(o['dp_amount']))}';
    if (st == 40 && cst == 2) return '清偿金 ${fmtMoney(toD(o['dp_amount']))} 已到账，可以去一键清偿了';
    if (st == 60) return '退款审核中，一般 1 个工作日内处理';
    if (st == 70) return '已原路退款，本单清偿金不再返还';
    return '';
  }

  Widget _flow(int st, int? cst) {
    final step = st == 70 || st == 50 ? -1 : (cst == 2 ? 4 : cst == 1 ? 3 : st >= 30 && st != 60 ? 2 : st >= 20 ? 1 : 0);
    const labels = ['下单', '支付', '收货', '保障期', '清偿金到账'];
    return Row(children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(child: Column(children: [
          Icon(i <= step ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: i <= step ? Sx.gold : Colors.white30),
          const SizedBox(height: 3),
          Text(labels[i], style: TextStyle(fontSize: 10.5, color: i <= step ? Colors.white : Colors.white38, fontWeight: FontWeight.w600)),
        ])),
    ]);
  }

  Future<void> _act(MallState m, String action, String ok) async {
    await mallRun(context, () => m.orderAction(widget.id, action), success: ok);
    if (mounted) _k.currentState?.reload();
  }

  Future<void> _refund(MallState m) async {
    final ctl = TextEditingController(text: '不想要了');
    final reason = await showDialog<String>(context: context, builder: (dc) => AlertDialog(
      title: const Text('申请退款'),
      content: TextField(controller: ctl, decoration: const InputDecoration(labelText: '退款原因')),
      actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dc, ctl.text), child: const Text('提交'))],
    ));
    if (reason == null || !mounted) return;
    await mallRun(context, () => m.orderAction(widget.id, 'refund', {'reason': reason}), success: '退款申请已提交');
    _k.currentState?.reload();
  }
}
