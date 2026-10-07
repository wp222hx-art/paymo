import 'package:flutter/material.dart';

import '../../core/module_info.dart';
import '../../core/theme.dart';
import 'common.dart';

/// AppBar 上的「?」按钮 → 弹出模块专业说明
class InfoButton extends StatelessWidget {
  final ModuleInfo info;
  const InfoButton(this.info, {super.key});
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '模块说明',
      icon: const Icon(Icons.help_outline),
      onPressed: () => showModuleInfo(context, info),
    );
  }
}

void showModuleInfo(BuildContext context, ModuleInfo info) {
  showXSheet(
    context,
    ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(20),
      children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [info.color, info.color.withValues(alpha: 0.7)]), borderRadius: BorderRadius.circular(16)),
            child: Icon(info.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(info.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(info.code, style: const TextStyle(fontSize: 11, color: XgColors.textSecondary, fontFamily: 'monospace')),
          ])),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: info.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: info.color, width: 3))),
          child: Text(info.tagline, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: info.color, height: 1.4)),
        ),
        const SizedBox(height: 14),
        Text(info.description, style: const TextStyle(fontSize: 13, height: 1.7, color: XgColors.textPrimary)),
        const SizedBox(height: 16),
        const Text('关键能力', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        ...info.highlights.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_circle, size: 16, color: info.color),
                const SizedBox(width: 8),
                Expanded(child: Text(h, style: const TextStyle(fontSize: 13, height: 1.5))),
              ]),
            )),
        const SizedBox(height: 10),
        const Text('相关接口', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: XgColors.navyDark, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: info.apis.map((a) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(a, style: const TextStyle(color: XgColors.gold, fontFamily: 'monospace', fontSize: 11)))).toList()),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}

/// 页面顶部「专业信息条」：一句话定位 + 查看详情
class ModuleBanner extends StatelessWidget {
  final ModuleInfo info;
  const ModuleBanner(this.info, {super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModuleInfo(context, info),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: info.color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(info.icon, size: 15, color: info.color),
          const SizedBox(width: 8),
          Expanded(child: Text('${info.code} · ${info.tagline}', style: TextStyle(fontSize: 11, color: info.color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Icon(Icons.info_outline, size: 14, color: info.color.withValues(alpha: 0.7)),
        ]),
      ),
    );
  }
}

/// 「这笔消费可抵多少债」情绪价值徽章
class DebtImpactBadge extends StatelessWidget {
  final double dp;
  final double monthlyRepayment; // 用于换算"相当于少还 N 天"
  final bool compact;
  const DebtImpactBadge({super.key, required this.dp, required this.monthlyRepayment, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final days = monthlyRepayment <= 0 ? 0 : dp / (monthlyRepayment / 30);
    final text = compact
        ? '抵债 ${dp.toStringAsFixed(dp == dp.roundToDouble() ? 0 : 1)} DP'
        : '这笔消费可抵债 ${dp.toStringAsFixed(dp == dp.roundToDouble() ? 0 : 1)} DP${days >= 0.5 ? ' ≈ 少还 ${days.toStringAsFixed(1)} 天' : ''}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(gradient: XgColors.sunrise, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: XgColors.coral.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wb_sunny_outlined, size: compact ? 12 : 14, color: Colors.white),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.white, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// 品牌 Logo（新图标）
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 48});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset('assets/icons/app_icon.png', width: size, height: size, fit: BoxFit.cover),
    );
  }
}
