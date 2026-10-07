import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../core/module_info.dart';
import '../admin/admin_pages.dart';
import '../widgets/module_widgets.dart';
import 'onboarding_page.dart';
import '../widgets/common.dart';
import 'community_page.dart';
import 'debt_pages.dart';
import 'debt_points_pages.dart';
import 'home_page.dart';
import 'shell_page.dart';
import 'wallet_pages.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final me = s.me;
    return Scaffold(
      appBar: const XgAppBar(title: '我的 · D01 用户域', info: Modules.profile),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const ModuleBanner(Modules.profile),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: XCard(
              margin: EdgeInsets.zero,
              gradient: XgColors.navyGradient,
              child: Row(children: [
                Avatar(me, size: 64),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(me.nickname, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Tag(me.role.label, color: XgColors.navyDark, bg: XgColors.gold),
                  ]),
                  const SizedBox(height: 4),
                  Text('${me.occupation} · ${me.city} · ${me.mbti}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('uuid ${me.uuid.substring(0, 8)}… · 邀请码 ${me.inviteCode}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Tag(KycLevel.name(me.kycLevel), color: Colors.white, bg: Colors.white.withValues(alpha: 0.2)),
                    const SizedBox(width: 6),
                    Tag('风险 ${['低', '中', '高', '极高'][me.riskLevel]}', color: Colors.white, bg: [XgColors.success, XgColors.warning, XgColors.danger, XgColors.danger][me.riskLevel].withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Tag(me.status.label, color: Colors.white, bg: me.status == UserStatus.normal ? XgColors.success.withValues(alpha: 0.7) : XgColors.danger.withValues(alpha: 0.7)),
                  ]),
                ])),
              ]),
            ),
          ),
          if (!me.role.isAdmin && !me.role.isBank)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                StatTile(label: '光芒值', value: fmtInt(me.lightPoints), icon: Icons.bolt, color: XgColors.goldDark),
                const SizedBox(width: 8),
                StatTile(label: '价值分', value: me.valueScore.toStringAsFixed(0), icon: Icons.cloud_outlined, color: XgColors.violet),
                const SizedBox(width: 8),
                StatTile(label: '信用重塑', value: '${me.creditScore}', icon: Icons.verified_outlined, color: XgColors.success),
              ]),
            ),

          // KYC 五级
          const SectionTitle('KYC 五级认证 · A-203'),
          XCard(
            child: Column(children: [
              for (int l = 1; l <= 5; l++) _KycRow(level: l, current: me.kycLevel),
            ]),
          ),

          const SectionTitle('功能'),
          XCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              if (!me.role.isAdmin && !me.role.isBank) ...[
                _item(context, Icons.account_balance_outlined, '债务中心 · 负债画像 / 还款方案', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtCenterPage()))),
                _item(context, Icons.token_outlined, '债务积分 · 银行清缴 / 结清证明（${s.myAvailablePoints.toStringAsFixed(0)} DP）', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtPointsPage()))),
                _item(context, Icons.shopping_bag_outlined, '消费平债商城 · 利润 × 倍率抵债', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OffsetShopPage()))),
                _item(context, Icons.account_balance_wallet_outlined, '钱包 · 充值 / 提现 / 光芒值', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()))),
                _item(context, Icons.cloud_outlined, 'AI 价值云 · 能力标签 / 成长体系', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ValueCloudPage()))),
                _item(context, Icons.article_outlined, '我的内容（${s.myContents.length}）', () => _myContents(context)),
              ],
              _item(context, Icons.menu_book_outlined, '复式账本 · LedgerEntry', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerPage()))),
              _item(context, Icons.terminal_outlined, 'API 调用日志 · 统一响应 / 错误码', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApiConsolePage()))),
              _item(context, Icons.devices_outlined, '登录设备 · API-U-014', () => _devices(context)),
              _item(context, Icons.privacy_tip_outlined, '隐私中心 · U-106', () => _privacy(context)),
              _item(context, Icons.key_outlined, '权限点（${me.permissions.length}）· RBAC + ABAC', () => _perms(context), last: true),
            ]),
          ),

          const SectionTitle('账号'),
          XCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _item(context, Icons.swap_horiz, '切换身份', () => showUserSwitcher(context)),
              _item(context, Icons.school_outlined, '重新查看使用引导', () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => OnboardingPage(onDone: () => Navigator.pop(context))))),
              _item(context, Icons.edit_outlined, '修改昵称 · API-U-002', () => _rename(context)),
              _item(context, Icons.logout, '退出登录 · API-A-008', () => s.logout(), last: true, danger: true),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext c, IconData i, String t, VoidCallback onTap, {bool last = false, bool danger = false}) {
    return Column(children: [
      ListTile(
        leading: Icon(i, color: danger ? XgColors.danger : XgColors.navy, size: 22),
        title: Text(t, style: TextStyle(fontSize: 14, color: danger ? XgColors.danger : XgColors.textPrimary)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: XgColors.textSecondary),
        onTap: onTap,
        dense: true,
      ),
      if (!last) const Divider(indent: 54),
    ]);
  }

  void _myContents(BuildContext context) {
    showXSheet(context, title: '我的内容', Consumer<AppState>(builder: (_, s, __) => ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 8), children: [
      if (s.myContents.isEmpty) const EmptyHint('还没有发布内容'),
      ...s.myContents.map((c) => ContentCard(c, showModeration: true)),
    ])));
  }

  void _devices(BuildContext context) async {
    final s = context.read<AppState>();
    final r = await s.call('GET', '/v1/auth/sessions', apiId: 'API-A-018');
    if (!context.mounted || !r.ok) return;
    final list = r.data['list'] as List;
    showXSheet(context, title: '登录设备 · 会话管理', ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
      ...list.map((d) => XCard(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), child: Row(children: [
        Icon(d['device'].toString().contains('Chrome') ? Icons.laptop_mac : Icons.phone_iphone, color: XgColors.navy),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['device'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), Text('${d['city']} · ${d['last_active']}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary))])),
        if (d['current'] == true) const Tag('当前', color: XgColors.success) else TextButton(onPressed: () async {
          final rr = await s.call('DELETE', '/v1/auth/sessions/${d['id']}', apiId: 'API-A-019');
          if (context.mounted) showApiResult(context, rr, successText: '已远程下线 ${d['id']}');
        }, child: const Text('下线', style: TextStyle(fontSize: 12, color: XgColors.danger))),
      ]))),
      const Text('设备指纹绑定 · 异地/新设备登录触发 A-208 风险登录二次验证', style: TextStyle(fontSize: 11, color: XgColors.textSecondary)),
      const SizedBox(height: 16),
    ]));
  }

  void _privacy(BuildContext context) {
    final s = context.read<AppState>();
    final sw = {'生日': true, '所在城市': true, '负债画像对好友可见': false, '价值云对商家可见': true, '个性化推荐': true, '营销消息': false};
    showXSheet(context, title: '隐私中心 · 字段级开关', StatefulBuilder(builder: (ctx, setSt) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
      ...sw.keys.map((k) => SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(k, style: const TextStyle(fontSize: 14)), value: sw[k]!, onChanged: (v) async {
        setSt(() => sw[k] = v);
        await s.call('PATCH', '/v1/users/me/privacy', apiId: 'API-U-012', body: {'field': k, 'enabled': v});
      })),
      const Divider(),
      ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.download_outlined), title: const Text('数据可携权 · 导出我的数据', style: TextStyle(fontSize: 14)), onTap: () => showApiResult(ctx, ApiResponse(code: 0, message: 'success', traceId: 'tr-export', serverTime: 0), successText: '导出任务已创建，24h 内邮件送达')),
      ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.delete_forever_outlined, color: XgColors.danger), title: const Text('申请注销 · 15 日冷静期 · API-U-013', style: TextStyle(fontSize: 14, color: XgColors.danger)), onTap: () async {
        final r = await s.call('POST', '/v1/users/me/deactivate', apiId: 'API-U-013', kycRequired: 3);
        if (ctx.mounted) showApiResult(ctx, r, successText: '已进入注销中（4）· 15 日冷静期可撤销');
      }),
      const SizedBox(height: 16),
    ])));
  }

  void _perms(BuildContext context) {
    final me = context.read<AppState>().me;
    showXSheet(context, title: '权限点 · {domain}.{module}.{action}', ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
      Text('角色 ${me.role.label} · RBAC 绑定 + ABAC 动态决策（资源归属 / KYC / 风险等级）· 网关 PDP 集中鉴权', style: const TextStyle(fontSize: 12, color: XgColors.textSecondary)),
      const SizedBox(height: 10),
      ...me.permissions.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.check_circle, size: 16, color: XgColors.success), const SizedBox(width: 8), Text(p, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))]))),
      const SizedBox(height: 16),
    ]));
  }

  void _rename(BuildContext context) {
    final s = context.read<AppState>();
    final ctrl = TextEditingController(text: s.me.nickname);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('修改昵称'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '2~20 字符 · 不含敏感词 · 每年可改 3 次')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () async {
          final r = await s.call('PATCH', '/v1/users/me', apiId: 'API-U-002', body: {'nickname': ctrl.text});
          if (!ctx.mounted) return;
          showApiResult(ctx, r, successText: '昵称已更新');
          if (r.ok) Navigator.pop(ctx);
        }, child: const Text('保存')),
      ],
    ));
  }
}

class _KycRow extends StatelessWidget {
  final int level;
  final int current;
  const _KycRow({required this.level, required this.current});
  @override
  Widget build(BuildContext context) {
    final done = current >= level;
    final next = current + 1 == level;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? XgColors.navy : (next ? XgColors.gold : XgColors.bg), border: Border.all(color: done || next ? Colors.transparent : XgColors.divider)),
          alignment: Alignment.center,
          child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : Text('L$level', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: next ? XgColors.navyDark : XgColors.textSecondary)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('L$level ${KycLevel.names[level]}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: done ? XgColors.textPrimary : XgColors.textSecondary)),
          Text('${KycLevel.unlocks[level]} · 限额 ${KycLevel.limits[level] == 0 ? '—' : fmtMoney(KycLevel.limits[level])}', style: const TextStyle(fontSize: 11, color: XgColors.textSecondary)),
        ])),
        if (next) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12), backgroundColor: XgColors.gold, foregroundColor: XgColors.navyDark), onPressed: () => _upgrade(context, level), child: const Text('去认证', style: TextStyle(fontSize: 12))),
      ]),
    );
  }

  void _upgrade(BuildContext context, int level) {
    final s = context.read<AppState>();
    if (level == 2) {
      final name = TextEditingController(text: s.me.nickname);
      final idc = TextEditingController(text: '330106199203154417');
      showXSheet(context, title: 'L2 实名认证 · API-A-010', ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: '真实姓名', hintText: '^[\\u4e00-\\u9fa5·]{2,30}\$')),
        const SizedBox(height: 10),
        TextField(controller: idc, decoration: const InputDecoration(labelText: '身份证号', hintText: '18 位 · GB 11643 校验位 · 尾号 0000 模拟三要素不一致')),
        const SizedBox(height: 8),
        const Text('公安三要素核验 · 幂等 60s · 每日 5 次 · Consent Hash 存证', style: TextStyle(fontSize: 11, color: XgColors.textSecondary)),
        const SizedBox(height: 16),
        FilledButton(onPressed: () async {
          final r = await s.call('POST', '/v1/auth/kyc/l2/verify', apiId: 'API-A-010', requestId: 'kyc2-${idc.text}', body: {'real_name': name.text, 'id_card_no': idc.text, 'consent_hash': 'sha256:demo'});
          if (!context.mounted) return;
          showApiResult(context, r, successText: 'L2 实名认证通过 · ${r.data?['kyc_record_id']}');
          if (r.ok) Navigator.pop(context);
        }, child: const Text('提交核验')),
        const SizedBox(height: 16),
      ]));
    } else if (level == 3) {
      showXSheet(context, title: 'L3 活体检测 · API-A-011', _Liveness(onDone: () async {
        final r = await s.call('POST', '/v1/auth/kyc/l3/liveness', apiId: 'API-A-011', body: {'mode': 'action'});
        if (!context.mounted) return;
        showApiResult(context, r, successText: '活体通过 · 分数 ${r.data?['liveness_score']} · 存证 ${r.data?['video_evidence_id']}');
        if (r.ok) Navigator.pop(context);
      }));
    } else if (level == 4) {
      final card = TextEditingController(text: '6222 0212 3456 7890 3');
      showXSheet(context, title: 'L4 银行卡四要素 · API-A-012', ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        TextField(controller: card, decoration: const InputDecoration(labelText: '银行卡号', hintText: 'Luhn 校验 + BIN 表')),
        const SizedBox(height: 8),
        const Text('四要素：卡号 + 姓名 + 身份证 + 预留手机号 · 小额打款验证 · 通过后解锁提现 / 分成 / 代扣', style: TextStyle(fontSize: 11, color: XgColors.textSecondary)),
        const SizedBox(height: 16),
        FilledButton(onPressed: () async {
          final r = await s.call('POST', '/v1/auth/kyc/l4/bank-card', apiId: 'API-A-012', body: {'bank_card_no': card.text});
          if (!context.mounted) return;
          showApiResult(context, r, successText: 'L4 通过 · ${r.data?['bank']} · 小额打款 ¥${r.data?['micro_deposit']}');
          if (r.ok) Navigator.pop(context);
        }, child: const Text('提交验证')),
        const SizedBox(height: 16),
      ]));
    } else {
      showApiResult(context, ApiResponse(code: 40303, message: 'L5 企业认证需提交营业执照 + 法人活体 + 对公打款，请前往商家入驻通道', traceId: 'tr-l5', serverTime: 0));
    }
  }
}

class _Liveness extends StatefulWidget {
  final Future<void> Function() onDone;
  const _Liveness({required this.onDone});
  @override
  State<_Liveness> createState() => _LivenessState();
}

class _LivenessState extends State<_Liveness> {
  int _step = 0;
  final steps = ['请正对摄像头', '请缓慢眨眼', '请向左转头', '请张嘴', '活体检测完成 ✓'];
  @override
  void initState() {
    super.initState();
    _run();
  }

  void _run() async {
    for (int i = 1; i < steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _step = i);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) await widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: XgColors.sunrise, boxShadow: [BoxShadow(color: XgColors.violet.withValues(alpha: 0.3), blurRadius: 24)]),
          alignment: Alignment.center,
          child: Icon(_step == steps.length - 1 ? Icons.verified_user : Icons.face_retouching_natural, size: 72, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(steps[_step], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('动作活体 · 阿里云 eKYC · 视频存证加密（SM4）· 仅白名单员工可访问', style: TextStyle(fontSize: 11, color: XgColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: _step / (steps.length - 1), color: XgColors.violet, backgroundColor: XgColors.divider),
        const SizedBox(height: 24),
      ]),
    );
  }
}
