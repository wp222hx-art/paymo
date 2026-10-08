import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/module_widgets.dart';

class _Step {
  final String title;
  final String body;
  final IconData icon;
  final List<Color> grad;
  final List<(String, String)> facts;
  const _Step(this.title, this.body, this.icon, this.grad, this.facts);
}

/// 按角色 / 步序挑一张电影级大图
String _heroFor(UserRole role, int i) {
  switch (role) {
    case UserRole.bankOfficer:
      return const ['assets/onboarding/step1.jpg', 'assets/onboarding/step2.jpg', 'assets/bg/home_hero.jpg', 'assets/onboarding/step5.jpg'][i % 4];
    case UserRole.riskOfficer:
      return const ['assets/onboarding/step5.jpg', 'assets/onboarding/step4.jpg', 'assets/onboarding/step2.jpg'][i % 3];
    case UserRole.opsManager:
      return const ['assets/bg/home_hero.jpg', 'assets/onboarding/step4.jpg', 'assets/onboarding/step3.jpg'][i % 3];
    case UserRole.merchant:
      return const ['assets/onboarding/step1.jpg', 'assets/onboarding/step4.jpg', 'assets/onboarding/step3.jpg'][i % 3];
    default:
      return 'assets/onboarding/step${(i % 5) + 1}.jpg';
  }
}

/// 使用引导：按角色呈现不同的 4~5 步
class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingPage({super.key, required this.onDone});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _ctrl = PageController();
  int _idx = 0;

  List<_Step> _steps(UserRole role) {
    switch (role) {
      case UserRole.bankOfficer:
        return const [
          _Step('欢迎接入新光云开放平台', '您将代表债权机构处理用户转交的债务积分清缴单。所有操作均通过 AppKey + HMAC-SHA256 签名，数据按机构租户隔离。', Icons.account_balance, [XgColors.success, Color(0xFF059669)], [('接入方式', 'Kong-Open 网关'), ('租户隔离', 'ABAC 策略')]),
          _Step('受理 → 确认收款 → 核销', '清缴单到达后：核验 Consent 与积分背书比例 → 确认平台存管汇款到账（银联流水）→ 按积分面值核销债务，可选择是否接受协商减免。', Icons.how_to_reg, [XgColors.navy, XgColors.navyLight], [('状态机', '10→20→30→40→50'), ('退回', '积分精确回滚')]),
          _Step('批量核销与日终对账', '多笔「资金划付」单据可一键批量核销（原子事务）。每日 00:05 自动生成对账 CSV，比对平台汇出 / 银行实收 / 核销金额，差错进入处理队列。', Icons.fact_check_outlined, [XgColors.info, Color(0xFF1D4ED8)], [('对账', 'T+1 · SM3 校验'), ('批量', '≤ 50 笔/批')]),
          _Step('签发《债务结清证明》', '案件余额归零后，由您签发结清证明（SM2 电子签章），通过 Webhook CERTIFICATE.ISSUED 实时推送用户。这是用户上岸的里程碑时刻。', Icons.workspace_premium, [XgColors.goldDark, XgColors.gold], [('签章', 'SM2 国密'), ('征信', '5 年后自动消除')]),
        ];
      case UserRole.riskOfficer:
        return const [
          _Step('欢迎来到风控管理域', '您负责反欺诈、AML、行为风控与资金风控。九大校验节点命中规则后生成案件，等待您处置。', Icons.shield_outlined, [XgColors.danger, Color(0xFFB91C1C)], [('风险等级', 'L1~L4'), ('SLA', 'L4 1h 应急')]),
          _Step('案件处置四级策略', 'L1 记录提醒 · L2 二次验证 · L3 冻结金额 · L4 封禁上报。处置结果实时作用于用户状态机，并写入 WORM 审计。', Icons.gavel_outlined, [XgColors.warning, Color(0xFFD97706)], [('审计', '不可篡改 5 年'), ('误报', '可降级回填')]),
          _Step('规则引擎', 'Drools DSL 规则可视化配置，支持灰度与 AB 对比。发布到生产需审批流。误报率回填驱动规则持续迭代。', Icons.rule_folder_outlined, [XgColors.navy, XgColors.navyLight], [('引擎', 'Drools + PMML'), ('灰度', '按比例切流')]),
        ];
      case UserRole.opsManager:
        return const [
          _Step('欢迎来到运营管理域', '北极星指标是「月度赎回进度总额」——它随每一笔银行核销回执实时跳动。', Icons.dashboard_outlined, [XgColors.navy, XgColors.navyLight], [('北极星', '赎回总额'), ('刷新', '实时')]),
          _Step('三审制内容审核', 'AI 初审 12 维度 → 分数 ≥ 90 直通；涉金融 / 负债 / 催收敏感类目转人工复审（SLA 30 min）；< 30 直接拦截并生成风控案件。', Icons.fact_check_outlined, [XgColors.violet, Color(0xFF6D28D9)], [('AIGC', '必须标注'), ('SLA', '≤ 30 min')]),
          _Step('平债倍率规则引擎', '抵债 DP = 平台利润 × min(品类基础倍率 + 信用加成, 全局上限)。您可以调品类倍率、设信用阶梯；生产规则改值自动降灰度，发布需审批。', Icons.tune_outlined, [XgColors.coral, XgColors.violet], [('上限', 'CFO 红线'), ('快照', '下单可审计')]),
        ];
      case UserRole.merchant:
        return const [
          _Step('欢迎入驻新光云', '您是任务发布方 / 品牌方。发布任务需缴纳保证金（奖励 × 人数），冻结至结算。', Icons.storefront_outlined, [XgColors.navy, XgColors.navyLight], [('认证', 'L5 企业'), ('保证金', '履约担保')]),
          _Step('AI 匹配与验收', '一键 AI 匹配候选人（基于价值云 Embedding）；交付物经 AI 初验后到您这里验收，72h 未响应自动通过。', Icons.how_to_reg, [XgColors.info, Color(0xFF1D4ED8)], [('AI 初验', '原创性 ≥ 60'), ('自动通过', '72h')]),
          _Step('分账与社会价值', '验收通过即自动分账：接单人现金 / 还债积分 / 平台费。您每一笔任务支出，都在帮一位负债人照亮未来。', Icons.volunteer_activism_outlined, [XgColors.coral, XgColors.violet], [('分账', '三方可配'), ('Webhook', 'SETTLEMENT.CREATED')]),
        ];
      default:
        return const [
          _Step('欢迎来到新光云', '这不是一个催你还钱的 App。这里的每一个功能，都是为了让"还债"这件事变得可以被看见、被规划、被一点点完成。', Icons.wb_twilight, [XgColors.navy, XgColors.navyLight], [('赎回进度', '真实数据'), ('合规', '金融级')]),
          _Step('两条平债通道', '① 还款计划：AI 规划师生成方案，确认后按月现金直付。② 债务积分：任务 / 内容 / 消费 / 光芒值产生的积分，转交银行核销。两条通道并行，余额归零即获结清证明。', Icons.alt_route, [XgColors.goldDark, XgColors.gold], [('1 DP', '= ¥1 抵扣'), ('现金背书', '真实汇款')]),
          _Step('边消费，边平债', '该花的钱照花。电影票、咖啡、话费、生鲜走平台商城，平台利润按倍率变成你的债务积分。信用重塑分越高，同样消费抵得越多。', Icons.shopping_bag_outlined, [XgColors.coral, XgColors.violet], [('利润 ¥5', '→ 25+ DP'), ('信用加成', '最高 +1.5')]),
          _Step('用能力赚钱', '任务市场由 AI 接单助手按你的能力标签匹配；收益按你设定的比例自动划入还债。内容创作同样如此——真实经历是最有力量的内容。', Icons.work_outline, [XgColors.info, Color(0xFF1D4ED8)], [('AI 派单', 'Top-N 匹配'), ('分账', '还债 60% 可调')]),
          _Step('8 位 AI 陪伴者', '债务规划师帮你算账，赋能教练陪你打卡，谈判专家替你写协商函，法务顾问守住催收边界……他们读得懂你的处境，也调得动真实业务接口。', Icons.auto_awesome, [XgColors.violet, Color(0xFF6D28D9)], [('模型', '多路由'), ('记忆', 'Fact Card')]),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final steps = _steps(s.me.role);
    final last = _idx == steps.length - 1;
    return Scaffold(
      backgroundColor: XgColors.navyDark,
      body: Stack(fit: StackFit.expand, children: [
        // 电影级背景大图（随页切换淡入淡出）
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
          child: SizedBox.expand(
            key: ValueKey(_idx),
            child: Image.asset(_heroFor(s.me.role, _idx), fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
        ),
        // 上下渐隐遮罩，保证文字可读
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.18, 0.42, 0.68, 1.0],
              colors: [Color(0xB3071A3A), Color(0x00071A3A), Color(0x00071A3A), Color(0xE6071A3A), Color(0xFF071A3A)],
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(children: [
                const BrandMark(size: 38),
                const SizedBox(width: 10),
                const Text('新光云 · 使用引导', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
                const Spacer(),
                TextButton(onPressed: widget.onDone, child: const Text('跳过', style: TextStyle(color: Colors.white70))),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _idx = i),
                itemCount: steps.length,
                itemBuilder: (_, i) {
                  final st = steps[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: st.grad, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: st.grad.first.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 6))]),
                          child: Icon(st.icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Text('STEP ${i + 1} / ${steps.length}', style: const TextStyle(color: XgColors.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
                      ]),
                      const SizedBox(height: 16),
                      Text(st.title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, shadows: [Shadow(color: Colors.black54, blurRadius: 12)])),
                      const SizedBox(height: 12),
                      Text(st.body, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14.5, height: 1.7)),
                      const SizedBox(height: 18),
                      Row(children: st.facts.map((f) => Expanded(child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.$1, style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(f.$2, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      ))).toList()),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
              child: Row(children: [
                ...List.generate(steps.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 250), width: i == _idx ? 22 : 6, height: 6, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: i == _idx ? XgColors.gold : Colors.white30, borderRadius: BorderRadius.circular(3)))),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: XgColors.gold, foregroundColor: XgColors.navyDark, minimumSize: const Size(148, 48), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  onPressed: () {
                    if (last) {
                      widget.onDone();
                    } else {
                      _ctrl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
                    }
                  },
                  child: Text(last ? '开始使用' : '下一步'),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
