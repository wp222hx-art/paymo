import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/mall_state.dart';
import 'mall_shell.dart';
import 'mall_widgets.dart';
import 'staff_pages.dart';

/// 根路由：按登录状态与账号角色进入不同界面
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});
  @override
  Widget build(BuildContext context) {
    final m = context.watch<MallState>();
    if (!m.booted) return const _Splash();
    if (!m.loggedIn) return const LoginPage2();
    if (m.me == null) {
      if (m.connectError != null) {
        return Scaffold(backgroundColor: Sx.bg, body: MallGate(builder: (_, __) => const SizedBox()), bottomNavigationBar: SafeArea(child: TextButton(onPressed: m.logout, child: const Text('返回登录'))));
      }
      return const _Splash();
    }
    return switch (m.role) {
      'merchant' => const MerchantShell(),
      'bank' => const BankShell(),
      'risk' || 'ops' => const RiskShell(),
      _ => const MallShell(),
    };
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Sx.ink,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome_rounded, color: Sx.gold, size: 44),
          SizedBox(height: 14),
          Text('星光云', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
          SizedBox(height: 22),
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Sx.gold)),
        ])),
      );
}

class LoginPage2 extends StatefulWidget {
  const LoginPage2({super.key});
  @override
  State<LoginPage2> createState() => _LoginPage2State();
}

/// 登录：选择身份 → 登录
class _LoginPage2State extends State<LoginPage2> {
  String _sel = demoAccounts.first.$1;
  bool _busy = false;

  static const _roleIcon = {'U': (Icons.person_rounded, Sx.mint), 'M': (Icons.storefront_rounded, Sx.gold), 'B': (Icons.account_balance_rounded, Sx.blue), 'R': (Icons.shield_rounded, Sx.coral)};

  Future<void> _login() async {
    setState(() => _busy = true);
    await mallRun(context, () => context.read<MallState>().loginAs(_sel));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Sx.ink,
      body: Stack(children: [
        Positioned.fill(child: MallImage(mediaImg('login_bg'), radius: 0, full: true)),
        const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x55121A33), Color(0xEE121A33)], stops: [0.1, 0.5])))),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(padding: EdgeInsets.fromLTRB(24, top + 36, 24, 30), children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: const BoxDecoration(gradient: Sx.goldGrad, shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: Colors.white)),
                const SizedBox(width: 10),
                const Text('星光云', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3)),
              ]),
              const SizedBox(height: 30),
              const Text('会花钱，\n也会轻松清偿。', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.25)),
              const SizedBox(height: 8),
              const Text('日常消费返清偿金 · 碎片时间做微劳动 · 银行出具偿清证明', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(left: 4), child: Text('选择身份', style: Sx.h2)),
                  const SizedBox(height: 12),
                  for (final a in demoAccounts) _tile(a),
                  const SizedBox(height: 10),
                  SButton('登录', loading: _busy, onTap: _login),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tile((String, String, String) a) {
    final sel = a.$1 == _sel;
    final ic = _roleIcon[a.$1.substring(0, 1)] ?? _roleIcon['U']!;
    return GestureDetector(
      onTap: () => setState(() => _sel = a.$1),
      onDoubleTap: () {
        setState(() => _sel = a.$1);
        _login();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: sel ? Sx.goldSoft : Sx.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? Sx.gold : Colors.transparent, width: 1.5)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: ic.$2.withValues(alpha: 0.14), shape: BoxShape.circle), child: Icon(ic.$1, color: ic.$2, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Sx.ink)),
            const SizedBox(height: 2),
            Text(a.$3, style: Sx.small),
          ])),
          Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: sel ? Sx.gold : Sx.line),
        ]),
      ),
    );
  }
}
