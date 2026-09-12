import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _selected;
  final _code = TextEditingController(text: '123456');
  bool _sent = false;
  bool _loading = false;
  int _countdown = 0;

  Future<void> _send() async {
    final s = context.read<AppState>();
    final r = await s.call('POST', '/v1/auth/sms/send', apiId: 'API-A-009', body: {'mobile': '+86138****${_selected!.substring(2)}'});
    if (!mounted) return;
    showApiResult(context, r, successText: '验证码已发送（演示码 123456）');
    if (r.ok) {
      setState(() {
        _sent = true;
        _code.text = '123456';
        _countdown = 60;
      });
      _tick();
    }
  }

  void _tick() async {
    while (_countdown > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _countdown--);
    }
  }

  Future<void> _login() async {
    if (_selected == null) return;
    setState(() => _loading = true);
    final r = await context.read<AppState>().login(_selected!, _code.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (!r.ok) showApiResult(context, r);
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<AppState>().allUsers;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: XgColors.navyGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(gradient: XgColors.sunrise, borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.wb_twilight, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('新光云', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        Text('负债人赋能平台 · DebtFlow AI', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('让每一分努力，\n都照亮未来。', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 8),
                Text('流量还债闭环 · AI 价值云 · 金融级合规', style: TextStyle(color: XgColors.gold.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('选择演示身份', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text('多角色 · 同一套数据 · 不同权限与视图', style: TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                      const SizedBox(height: 14),
                      ...users.map((u) => _UserTile(user: u, selected: _selected == u.userId, onTap: () => setState(() => _selected = u.userId))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _code,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(hintText: '短信验证码（演示 123456）', counterText: '', prefixIcon: Icon(Icons.sms_outlined, size: 20)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 118,
                            child: OutlinedButton(
                              onPressed: _selected == null || _countdown > 0 ? null : _send,
                              child: Text(_countdown > 0 ? '${_countdown}s' : (_sent ? '重新发送' : '获取验证码'), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _selected == null || _loading ? null : _login,
                          child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('登录 · API-A-003 /v1/auth/login/sms'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined, size: 14, color: XgColors.textSecondary),
                          SizedBox(width: 6),
                          Expanded(child: Text('设备指纹绑定 · JWT + Refresh Token · 零信任网关', style: TextStyle(fontSize: 11, color: XgColors.textSecondary))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: Text('登录即代表同意《用户协议》《隐私政策》· Consent 记录将留存', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserProfile user;
  final bool selected;
  final VoidCallback onTap;
  const _UserTile({required this.user, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? XgColors.navy.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? XgColors.navy : XgColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Avatar(user, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(user.nickname, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 6),
                    Tag(user.role.label, color: user.role.isAdmin ? XgColors.violet : XgColors.navy),
                  ]),
                  const SizedBox(height: 2),
                  Text('${user.role.desc} · ${KycLevel.name(user.kycLevel)}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? XgColors.navy : XgColors.divider, size: 20),
          ],
        ),
      ),
    );
  }
}
