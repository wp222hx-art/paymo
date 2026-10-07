import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'debt_points_pages.dart';

/// 支付密码二次验证 · API-A-016（返回 5 分钟令牌）
Future<bool> verifyPayPassword(BuildContext context) async {
  final s = context.read<AppState>();
  final ctrl = TextEditingController(text: '888888');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('支付密码验证'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('敏感操作需二次验证（A-206 · 键盘乱序 · PBKDF2）。验证后颁发 5 分钟临时授权令牌。', style: TextStyle(fontSize: 12, color: XgColors.textSecondary)),
        const SizedBox(height: 12),
        TextField(controller: ctrl, obscureText: true, maxLength: 6, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '6 位支付密码（演示 888888）', counterText: '')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            final r = await s.call('POST', '/v1/auth/pay-password/verify', apiId: 'API-A-016', body: {'pay_password': ctrl.text});
            if (!ctx.mounted) return;
            if (!r.ok) {
              showApiResult(ctx, r);
              return;
            }
            Navigator.pop(ctx, true);
          },
          child: const Text('验证'),
        ),
      ],
    ),
  );
  return ok == true;
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me;
    return Scaffold(
      appBar: AppBar(title: const Text('钱包 · R-603 资金账户'), actions: [
        IconButton(icon: const Icon(Icons.menu_book_outlined), tooltip: '复式账本', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerPage()))),
      ]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.navyGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('可用余额（银行存管 II 类账户）', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(fmtMoney(me.walletBalance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                Text('冻结 ${fmtMoney(me.walletFrozen)} · ${KycLevel.name(me.kycLevel)} 单日限额 ${fmtMoney(KycLevel.limits[me.kycLevel])}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: XgColors.gold, foregroundColor: XgColors.navyDark), onPressed: () => _recharge(context), child: const Text('充值'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), onPressed: () => _withdraw(context), child: const Text('提现'))),
                ]),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.sunrise,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.bolt, color: Colors.white, size: 30),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${fmtInt(me.lightPoints)} 光芒值', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const Text('100 光芒值 = 1 DP 债务积分 · 不可提现 · 复式记账', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ])),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: XgColors.violet, minimumSize: const Size(0, 36)), onPressed: () => _redeem(context), child: const Text('兑换积分')),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtPointsPage())),
              child: Row(children: [
                const Icon(Icons.token_outlined, color: XgColors.goldDark, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.myAvailablePoints.toStringAsFixed(1)} DP 债务积分', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('现金背书 ${fmtMoney(s.myCashBacked)} · 转交银行清缴 → 结清证明', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
                ])),
                const Icon(Icons.chevron_right, color: XgColors.textSecondary),
              ]),
            ),
          ),
          const SectionTitle('结算记录 · API-T-014'),
          if (s.mySettlements.isEmpty) const EmptyHint('暂无结算'),
          ...s.mySettlements.map((st) => XCard(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Text(st.settlementId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const Spacer(), Text(fmtDate(st.createdAt), style: const TextStyle(fontSize: 11, color: XgColors.textSecondary))]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _split('总额', st.gross, XgColors.textPrimary),
                    _split('→ 还债', st.repayPart, XgColors.success),
                    _split('→ 提现', st.cashPart, XgColors.info),
                    _split('平台费', st.platformFee, XgColors.textSecondary),
                  ]),
                ]),
              )),
          const SectionTitle('资金流水 · API-R-012'),
          ...s.walletTxs.map((t) => _TxRow(t)),
        ],
      ),
    );
  }

  Widget _split(String l, double v, Color c) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)), Text(fmtMoney(v), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c))]));

  void _recharge(BuildContext context) {
    final s = context.read<AppState>();
    final ctrl = TextEditingController(text: '2000');
    String channel = 'wechat';
    showXSheet(
      context,
      title: '充值 · API-R-010',
      StatefulBuilder(
        builder: (ctx, setSt) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '金额（元）', prefixText: '¥ ')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final c in const [('wechat', '微信支付'), ('alipay', '支付宝'), ('unionpay', '云闪付'), ('ecny', '数字人民币')])
              ChoiceChip(label: Text(c.$2), selected: channel == c.$1, onSelected: (_) => setSt(() => channel = c.$1)),
          ]),
          const SizedBox(height: 8),
          const Text('R-607 多通道路由 · 幂等级别 L3（7 天） · 复式分录：支付通道待清算 D / 用户钱包 C', style: TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final r = await s.call('POST', '/v1/wallets/recharge', apiId: 'API-R-010', requestId: 'rc-${DateTime.now().millisecondsSinceEpoch}', body: {'amount': double.tryParse(ctrl.text) ?? 0, 'channel': channel});
              if (!ctx.mounted) return;
              showApiResult(ctx, r, successText: '充值成功 · 余额 ${fmtMoney(r.data?['balance'] ?? 0)} · Webhook PAYMENT.SUCCESS');
              if (r.ok) Navigator.pop(ctx);
            },
            child: const Text('确认支付'),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _withdraw(BuildContext context) {
    final s = context.read<AppState>();
    final ctrl = TextEditingController(text: '500');
    showXSheet(
      context,
      title: '提现 · API-R-011',
      ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '金额（元）', prefixText: '¥ ')),
        const SizedBox(height: 10),
        XCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('风控校验节点 · 提现', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text('KYC ≥ L4 · 单日限额 ${fmtMoney(KycLevel.limits[s.me.kycLevel])} · 金额 ≥ ¥5,000 且中风险 → 转人工电话核实 · 支付密码令牌 · T+1 到账', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
          ]),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            final tok = await verifyPayPassword(context);
            if (!tok || !context.mounted) return;
            final r = await s.call('POST', '/v1/wallets/withdraw', apiId: 'API-R-011', kycRequired: 4, permission: 'finance.wallet.withdraw', requirePayToken: true, requestId: 'wd-${DateTime.now().millisecondsSinceEpoch}', body: {'amount': double.tryParse(ctrl.text) ?? 0, 'card_tail': '6621'});
            if (!context.mounted) return;
            showApiResult(context, r, successText: '提现申请成功 · ${r.data?['arrival']} 到账');
            if (r.ok) Navigator.pop(context);
          },
          child: const Text('申请提现'),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  void _redeem(BuildContext context) {
    final s = context.read<AppState>();
    final ctrl = TextEditingController(text: '1000');
    showXSheet(
      context,
      title: '光芒值兑换债务积分',
      ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '光芒值（100 的整数倍）', suffixText: '✦')),
        const SizedBox(height: 8),
        const Text('100 光芒值 = 1 DP（现金背书 100%）。复式分录：平台待结算账户 D / 债务积分现金备付金 C。积分进入统一积分池，可转交银行清缴。', style: TextStyle(fontSize: 11, color: XgColors.textSecondary)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            final r = await s.call('POST', '/v1/wallets/light-points/redeem', apiId: 'API-R-008', body: {'points': int.tryParse(ctrl.text) ?? 0});
            if (!context.mounted) return;
            showApiResult(context, r, successText: '已兑换 ${r.data?['redeemed_points']} 光芒值 → +${(r.data?['debt_points_issued'] as num?)?.toStringAsFixed(1)} DP 债务积分');
            if (r.ok) Navigator.pop(context);
          },
          child: const Text('确认兑换'),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _TxRow extends StatelessWidget {
  final WalletTx t;
  const _TxRow(this.t);
  @override
  Widget build(BuildContext context) {
    final icon = switch (t.type) {
      'recharge' => Icons.add_card_outlined,
      'withdraw' => Icons.outbox_outlined,
      'repay' => Icons.account_balance_outlined,
      'task_income' => Icons.work_outline,
      'content_income' => Icons.play_circle_outline,
      'consumption' => Icons.shopping_bag_outlined,
      'debt_points' => Icons.token_outlined,
      _ => Icons.receipt_long_outlined,
    };
    final positive = t.amount >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: XgColors.divider)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (positive ? XgColors.success : XgColors.navy).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 20, color: positive ? XgColors.success : XgColors.navy)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
          Text('${t.txId} · ${fmtDate(t.createdAt)}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmtMoney(t.amount, sign: true), style: TextStyle(fontWeight: FontWeight.w700, color: positive ? XgColors.success : XgColors.textPrimary)),
          if (t.status != 'success') Tag(t.status == 'frozen' ? '风控冻结' : '处理中', color: t.status == 'frozen' ? XgColors.danger : XgColors.warning),
        ]),
      ]),
    );
  }
}

/// 复式账本 R-604
class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final entries = s.ledger;
    final txs = <String, List<LedgerEntry>>{};
    for (final e in entries) {
      txs.putIfAbsent(e.txId, () => []).add(e);
    }
    double d = 0, c = 0;
    for (final e in entries) {
      e.direction == 'D' ? d += e.amount : c += e.amount;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('复式账本 · R-604 LedgerEntry')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          XCard(
            margin: EdgeInsets.zero,
            gradient: XgColors.navyGradient,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('借贷平衡校验（每日凌晨自动）', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('累计借方 D', style: TextStyle(color: Colors.white70, fontSize: 11)), Text(fmtMoney(d), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('累计贷方 C', style: TextStyle(color: Colors.white70, fontSize: 11)), Text(fmtMoney(c), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))])),
                Column(children: [
                  Icon((d - c).abs() < 0.01 ? Icons.verified : Icons.warning_amber, color: (d - c).abs() < 0.01 ? XgColors.gold : XgColors.coral, size: 28),
                  Text((d - c).abs() < 0.01 ? '平衡' : '告警', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 8),
              const Text('🔒 只允许 INSERT · 禁止 UPDATE/DELETE · 错账红字冲销 · WORM 存储 · TiDB 强一致', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ]),
          ),
          const SizedBox(height: 12),
          ...txs.entries.map((tx) {
            final first = tx.value.first;
            return XCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Tag(tx.key, color: XgColors.navy),
                  const SizedBox(width: 6),
                  Tag(first.businessType, color: XgColors.violet),
                  const Spacer(),
                  Text(fmtDate(first.createdAt), style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Text('单据 ${first.businessRefId} · op_type ${['', '系统', '用户', 'AI', '后台'][first.opType]}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                const Divider(height: 14),
                Row(children: const [
                  Expanded(flex: 5, child: Text('会计科目', style: TextStyle(fontSize: 10, color: XgColors.textSecondary))),
                  Expanded(flex: 2, child: Text('借方', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: XgColors.textSecondary))),
                  Expanded(flex: 2, child: Text('贷方', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, color: XgColors.textSecondary))),
                ]),
                ...tx.value.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(flex: 5, child: Text(e.account, style: const TextStyle(fontSize: 12))),
                        Expanded(flex: 2, child: Text(e.direction == 'D' ? fmtMoney(e.amount) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: XgColors.info))),
                        Expanded(flex: 2, child: Text(e.direction == 'C' ? fmtMoney(e.amount) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: XgColors.success))),
                      ]),
                    )),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
