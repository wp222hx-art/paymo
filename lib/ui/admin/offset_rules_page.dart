import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/mock_db.dart';
import '../../state/app_state.dart';
import '../pages/shell_page.dart';
import '../widgets/common.dart';

/// 运营 · 平债倍率规则引擎（按品类 / 信用分 / 全局上限）
class OffsetRulesPage extends StatefulWidget {
  const OffsetRulesPage({super.key});
  @override
  State<OffsetRulesPage> createState() => _OffsetRulesPageState();
}

class _OffsetRulesPageState extends State<OffsetRulesPage> {
  int _simCredit = 612;
  String _simCategory = '本地生活';

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rules = s.offsetRules;
    final cats = rules.where((r) => r.ruleType == 'category').toList();
    final tiers = rules.where((r) => r.ruleType == 'credit_tier').toList()..sort((a, b) => (a.creditMin ?? 0).compareTo(b.creditMin ?? 0));
    final caps = rules.where((r) => r.ruleType == 'global_cap').toList();

    // 模拟器
    final live = rules.where((r) => r.status == 1 || r.status == 2);
    final cat = live.where((r) => r.ruleType == 'category' && r.category == _simCategory).firstOrNull;
    final tier = live.where((r) => r.ruleType == 'credit_tier' && _simCredit >= (r.creditMin ?? 0) && _simCredit <= (r.creditMax ?? 9999)).firstOrNull;
    final cap = live.where((r) => r.ruleType == 'global_cap').firstOrNull;
    final base = cat?.value ?? 0;
    final bonus = tier?.value ?? 0;
    final fin = (base + bonus).clamp(0, cap?.value ?? 99).toDouble();

    return Scaffold(
      appBar: XgAppBar(title: '平债倍率规则 · OP-107', actions: [
        IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () => _createSheet(context)),
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
                const Text('倍率公式', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                const Text('抵债 DP = 平台利润 × min(品类基础倍率 + 信用分加成, 全局上限)', style: TextStyle(color: XgColors.gold, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                const Text('信用分越高、履约越好的用户，同样消费可抵更多债务——正向激励还款行为；全局上限由财务设定，控制平台让利敞口。生产规则改值自动降为灰度，需重新审批发布。', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5)),
                const SizedBox(height: 12),
                Row(children: [
                  _m('生产规则', '${rules.where((r) => r.status == 2).length}'),
                  _m('灰度', '${rules.where((r) => r.status == 1).length}'),
                  _m('24h 命中', fmtInt(rules.fold(0, (a, r) => a + r.hitCount))),
                  _m('全局上限', '×${cap?.value.toStringAsFixed(1) ?? '-'}'),
                ]),
              ]),
            ),
          ),

          // 模拟器
          const SectionTitle('倍率模拟器 · 实时预览'),
          XCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: cats.map((c) => ChoiceChip(label: Text(c.category!, style: const TextStyle(fontSize: 12)), selected: _simCategory == c.category, onSelected: (_) => setState(() => _simCategory = c.category!))).toList()),
              const SizedBox(height: 8),
              Text('用户信用重塑分：$_simCredit', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Slider(value: _simCredit.toDouble(), min: 550, max: 800, divisions: 25, activeColor: XgColors.gold, onChanged: (v) => setState(() => _simCredit = v.round())),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: XgColors.bg, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('×${base.toStringAsFixed(1)} + ×${bonus.toStringAsFixed(1)}${base + bonus > fin ? ' → 触及上限' : ''}', style: const TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                    Text('最终倍率 ×${fin.toStringAsFixed(1)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: XgColors.navy)),
                    Text('命中：${[if (cat != null) cat.ruleId, if (tier != null) tier.ruleId, if (cap != null && base + bonus > fin) cap.ruleId].join(' · ')}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('利润 ¥5 示例', style: TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                    Text('${(5 * fin).toStringAsFixed(1)} DP', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: XgColors.coral)),
                  ]),
                ]),
              ),
            ]),
          ),

          const SectionTitle('品类基础倍率'),
          ...cats.map((r) => _RuleCard(r)),
          const SectionTitle('信用分加成（阶梯）'),
          ...tiers.map((r) => _RuleCard(r)),
          const SectionTitle('全局上限（财务红线）'),
          ...caps.map((r) => _RuleCard(r)),
        ],
      ),
    );
  }

  Widget _m(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(v, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)), Text(l, style: const TextStyle(color: Colors.white70, fontSize: 10))]));

  void _createSheet(BuildContext context) {
    final s = context.read<AppState>();
    String type = 'category';
    final name = TextEditingController(text: '文娱演出 · 基础倍率');
    final cat = TextEditingController(text: '文娱演出');
    final value = TextEditingController(text: '4');
    final cmin = TextEditingController(text: '600');
    final cmax = TextEditingController(text: '649');
    showXSheet(context, title: '新建倍率规则（草稿）', StatefulBuilder(builder: (ctx, setSt) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'category', label: Text('品类')), ButtonSegment(value: 'credit_tier', label: Text('信用加成')), ButtonSegment(value: 'global_cap', label: Text('全局上限'))],
        selected: {type},
        onSelectionChanged: (v) => setSt(() => type = v.first),
      ),
      const SizedBox(height: 12),
      TextField(controller: name, decoration: const InputDecoration(labelText: '规则名称')),
      const SizedBox(height: 10),
      if (type == 'category') TextField(controller: cat, decoration: const InputDecoration(labelText: '品类（需与 SKU category 一致）')),
      if (type == 'credit_tier') Row(children: [Expanded(child: TextField(controller: cmin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '信用分下限'))), const SizedBox(width: 10), Expanded(child: TextField(controller: cmax, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '上限')))]),
      const SizedBox(height: 10),
      TextField(controller: value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: type == 'credit_tier' ? '加成（0~10）' : '倍率（0~10）')),
      const SizedBox(height: 8),
      const Text('新规则以草稿创建 → 灰度（AB 对比）→ 发布需 ops.offset_rule.publish 审批。', style: TextStyle(fontSize: 11, color: XgColors.textSecondary)),
      const SizedBox(height: 14),
      FilledButton(onPressed: () async {
        final r = await s.call('POST', '/v1/admin/offset-rules', apiId: 'ADM-OP-107', permission: 'ops.offset_rule.write', body: {'rule_type': type, 'name': name.text, 'category': cat.text, 'credit_min': int.tryParse(cmin.text), 'credit_max': int.tryParse(cmax.text), 'value': double.tryParse(value.text)});
        if (!ctx.mounted) return;
        showApiResult(ctx, r, successText: '规则 ${r.data?['rule_id']} 已创建（草稿）');
        if (r.ok) Navigator.pop(ctx);
      }, child: const Text('创建草稿')),
      const SizedBox(height: 20),
    ])));
  }
}

class _RuleCard extends StatelessWidget {
  final OffsetRule r;
  const _RuleCard(this.r);
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final stColor = [XgColors.textSecondary, XgColors.warning, XgColors.success, XgColors.danger][r.status];
    final scope = switch (r.ruleType) {
      'category' => r.category ?? '',
      'credit_tier' => '${r.creditMin}~${r.creditMax == 999 ? '+' : r.creditMax}',
      _ => '全局',
    };
    final valueLabel = r.ruleType == 'credit_tier' ? '+${r.value.toStringAsFixed(1)}' : '×${r.value.toStringAsFixed(1)}';
    final skuCount = r.ruleType == 'category' ? MockDb.products.where((p) => p.category == r.category).length : null;
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(r.ruleId, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Tag(scope, color: XgColors.info),
          const Spacer(),
          Tag(r.statusLabel, color: stColor),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          Text(valueLabel, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: XgColors.navy)),
        ]),
        const SizedBox(height: 4),
        Text('命中 ${fmtInt(r.hitCount)} 次 · 创建 ${s.db.users[r.createdBy]?.nickname ?? r.createdBy}${r.approvedBy != null ? ' · 审批 ${r.approvedBy}' : ' · 未审批'}${skuCount != null ? ' · 覆盖 $skuCount 个 SKU' : ''}', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
        const SizedBox(height: 10),
        Row(children: [
          IconButton.outlined(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove, size: 16), onPressed: () => _setValue(context, s, r.value - 0.5)),
          const SizedBox(width: 4),
          IconButton.outlined(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add, size: 16), onPressed: () => _setValue(context, s, r.value + 0.5)),
          const Spacer(),
          for (final st in const [(1, '灰度'), (2, '发布'), (3, '关闭')])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 10), foregroundColor: st.$1 == 2 ? XgColors.success : (st.$1 == 3 ? XgColors.danger : XgColors.warning)),
                onPressed: r.status == st.$1 ? null : () async {
                  final rr = await s.call('PUT', '/v1/admin/offset-rules/${r.ruleId}', apiId: 'ADM-OP-107', permission: 'ops.offset_rule.write', body: {'status': st.$1});
                  if (context.mounted) showApiResult(context, rr, successText: '${r.ruleId} → ${st.$2}');
                },
                child: Text(st.$2, style: const TextStyle(fontSize: 11)),
              ),
            ),
        ]),
      ]),
    );
  }

  void _setValue(BuildContext context, AppState s, double v) async {
    final rr = await s.call('PUT', '/v1/admin/offset-rules/${r.ruleId}', apiId: 'ADM-OP-107', permission: 'ops.offset_rule.write', body: {'value': v});
    if (context.mounted) showApiResult(context, rr, successText: '${r.ruleId} 值 → ${(rr.data?['value'] as num?)?.toStringAsFixed(1)}${rr.data?['status'] == 1 ? '（已降为灰度，需重新发布）' : ''}');
  }
}
