import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import 'agent_pages.dart';
import 'shell_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  int _feed = 0; // 0 推荐 1 关注 2 同城

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    var list = s.feed;
    if (_feed == 1) list = list.where((c) => c.authorId != s.me.userId).toList();
    if (_feed == 2) list = list.where((c) => s.db.users[c.authorId]?.city == s.me.city).toList();
    return Scaffold(
      appBar: XgAppBar(title: '社区 · D04 / D08', actions: [
        IconButton(icon: const Icon(Icons.edit_note), tooltip: '发布内容', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateContentPage()))),
      ]),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<int>(
              segments: const [ButtonSegment(value: 0, label: Text('推荐'), icon: Icon(Icons.auto_awesome, size: 14)), ButtonSegment(value: 1, label: Text('关注')), ButtonSegment(value: 2, label: Text('同城'))],
              selected: {_feed},
              onSelectionChanged: (v) {
                setState(() => _feed = v.first);
                s.call('GET', '/v1/contents/feed/${['recommend', 'follow', 'nearby'][v.first]}', apiId: 'API-C-00${5 + v.first}');
              },
              style: ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          // 互助社群
          const SectionTitle('互助社群 · N-805'),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _circle('债务同盟', '12.4k', 0),
                _circle('心灵驿站', '8.9k', 1),
                _circle('共学计划', '5.2k', 2),
                _circle('杭州圈', '2.1k', 3),
                _circle('创作者联盟', '6.7k', 6),
              ],
            ),
          ),
          SectionTitle(['推荐流 · 协同过滤 + Embedding', '关注流', '同城流 · ${s.me.city}'][_feed]),
          if (list.isEmpty) const EmptyHint('暂无内容'),
          ...list.map((c) => ContentCard(c)),
        ],
      ),
    );
  }

  Widget _circle(String n, String m, int gi) {
    final g = XgColors.agentGradient(gi);
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(gradient: LinearGradient(colors: g), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        Text('$m 成员', style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }
}

class ContentCard extends StatelessWidget {
  final Content c;
  final bool showModeration;
  const ContentCard(this.c, {super.key, this.showModeration = false});
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final author = s.db.users[c.authorId];
    final typeIcon = switch (c.contentType) {
      2 || 3 => Icons.play_circle_fill,
      5 => Icons.headphones,
      4 || 6 => Icons.live_tv,
      _ => Icons.article,
    };
    return XCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (author != null) Avatar(author, size: 30) else Container(width: 30, height: 30, decoration: const BoxDecoration(color: XgColors.divider, shape: BoxShape.circle), alignment: Alignment.center, child: Text(c.authorName.substring(0, 1), style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(fmtDate(c.publishedAt), style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
          ])),
          Tag(c.typeLabel, color: XgColors.info, icon: typeIcon),
          if (c.aiGenerated) ...[const SizedBox(width: 4), const Tag('AI 生成', color: XgColors.violet, icon: Icons.auto_awesome)],
          if (showModeration) ...[const SizedBox(width: 4), Tag(c.modLabel, color: c.moderationStatus == 3 ? XgColors.danger : XgColors.warning)],
        ]),
        const SizedBox(height: 10),
        Text(c.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
        const SizedBox(height: 6),
        Text(c.body, style: const TextStyle(fontSize: 13, color: XgColors.textSecondary, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
        if (c.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: c.tags.map((t) => Text('#$t', style: const TextStyle(fontSize: 12, color: XgColors.navy))).toList()),
        ],
        if (c.revenueAmount > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: XgColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.wb_sunny_outlined, size: 14, color: XgColors.goldDark),
              const SizedBox(width: 6),
              Text('收益 ${fmtMoney(c.revenueAmount)} · 其中 ${fmtMoney(c.revenueRepayAmount)} 已流量还债', style: const TextStyle(fontSize: 11, color: XgColors.goldDark, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
        if (!showModeration) ...[
          const Divider(height: 20),
          Row(children: [
            _act(Icons.remove_red_eye_outlined, fmtInt(c.viewCount), null),
            _act(c.likedByMe ? Icons.favorite : Icons.favorite_border, fmtInt(c.likeCount), () async {
              final r = await s.call('POST', '/v1/contents/${c.contentId}/like', apiId: 'API-C-009', kycRequired: 1);
              if (!r.ok && context.mounted) showApiResult(context, r);
            }, color: c.likedByMe ? XgColors.coral : null),
            _act(Icons.chat_bubble_outline, fmtInt(c.commentCount), () async {
              final r = await s.call('POST', '/v1/contents/${c.contentId}/comments', apiId: 'API-C-012', kycRequired: 1, body: {'text': '加油，我们一起上岸！'});
              if (context.mounted) showApiResult(context, r, successText: '评论已发布（模拟）');
            }),
            _act(Icons.share_outlined, fmtInt(c.shareCount), () async {
              final r = await s.call('POST', '/v1/contents/${c.contentId}/share', apiId: 'API-C-011');
              if (context.mounted) showApiResult(context, r, successText: '归因短链已生成：${(r.data?['url'] as String?)?.split('?').first}');
            }),
            const Spacer(),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.flag_outlined, size: 18, color: XgColors.textSecondary), onPressed: () async {
              final r = await s.call('POST', '/v1/contents/${c.contentId}/report', apiId: 'API-C-014', body: {'reason': 'spam'});
              if (context.mounted) showApiResult(context, r, successText: '已举报 · 进入合规投诉队列 CP-303');
            }),
          ]),
        ],
      ]),
    );
  }

  Widget _act(IconData i, String t, VoidCallback? onTap, {Color? color}) => Padding(
    padding: const EdgeInsets.only(right: 18),
    child: InkWell(onTap: onTap, child: Row(children: [Icon(i, size: 18, color: color ?? XgColors.textSecondary), const SizedBox(width: 4), Text(t, style: TextStyle(fontSize: 12, color: color ?? XgColors.textSecondary))])),
  );
}

class CreateContentPage extends StatefulWidget {
  const CreateContentPage({super.key});
  @override
  State<CreateContentPage> createState() => _CreateContentPageState();
}

class _CreateContentPageState extends State<CreateContentPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  int _type = 1;
  bool _ai = false;
  final Set<String> _tags = {'真实经历'};

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('发布内容 · API-C-001')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            for (final t in const [(1, '图文'), (2, '短视频'), (5, '音频')])
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(t.$2), selected: _type == t.$1, onSelected: (_) => setState(() => _type = t.$1))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: '标题', hintText: '违禁词校验 · ≤120 字符')),
          TextField(controller: _body, minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: '正文', hintText: '至少 10 字符。试试包含"催收""停息"等词看看三审制如何流转；包含"加微""征信修复"会被 AI 初审直接拦截。')),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: ['真实经历', '流量还债', '理财科普', '谈判技巧', '法律科普', '心灵驿站', 'AI工具'].map((t) => FilterChip(label: Text(t, style: const TextStyle(fontSize: 12)), selected: _tags.contains(t), onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t)))).toList()),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _ai,
            onChanged: (v) => setState(() => _ai = v),
            title: const Text('本内容由 AI 全部/部分生成', style: TextStyle(fontSize: 14)),
            subtitle: const Text('合规硬要求：AIGC 必须标注（CP-307）。未标注但含 AI 字样将降分转人工。', style: TextStyle(fontSize: 11)),
          ),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => openAgent(context, 'AG-04'), icon: const Text('✨'), label: const Text('让创作助手写初稿', style: TextStyle(fontSize: 13)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => openAgent(context, 'AG-08'), icon: const Text('🛡️'), label: const Text('先问监管哨兵', style: TextStyle(fontSize: 13)))),
          ]),
          const SizedBox(height: 12),
          XCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('三审制 C-403', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 6),
              Text('0 待审 → AI 初审（12 维度）→ 分数 ≥ 90 且无敏感类目 → 1 AI 通过直接上线\n分数 < 90 或涉金融/负债/催收 → 人工复审队列（SLA 30 min）\n分数 < 30 → 3 拒绝 + 生成风控案件', style: TextStyle(fontSize: 11, color: XgColors.textSecondary, height: 1.5)),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final r = await s.call('POST', '/v1/contents', apiId: 'API-C-001', kycRequired: 2, permission: 'content.publish', body: {'title': _title.text, 'body': _body.text, 'content_type': _type, 'tags': _tags.toList(), 'ai_generated': _ai});
              if (!context.mounted) return;
              if (r.ok) {
                final ms = r.data['moderation_status'] as int;
                final score = (r.data['ai_score'] as num).toStringAsFixed(0);
                showApiResult(context, r, successText: ms == 1 ? 'AI 初审通过（$score 分）· 已发布' : (ms == 3 ? 'AI 初审拦截（$score 分）· ${r.data['reason']}' : 'AI 初审 $score 分 · 转人工复审：${r.data['reason']}'));
                Navigator.pop(context);
              } else {
                showApiResult(context, r);
              }
            },
            child: const Text('发布并触发 AI 初审'),
          ),
        ],
      ),
    );
  }
}
