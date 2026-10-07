import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/agent_service.dart';
import '../../state/app_state.dart';
import '../widgets/common.dart';
import '../../core/module_info.dart';
import '../widgets/module_widgets.dart';
import 'shell_page.dart';

void openAgent(BuildContext context, String code) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => AgentChatPage(agentCode: code)));
}

class AgentHubPage extends StatelessWidget {
  const AgentHubPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: const XgAppBar(title: 'AI 智能域 · D03', info: Modules.agents),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 10), child: ModuleBanner(Modules.agents)),
          XCard(
            gradient: XgColors.sunrise,
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.hub_outlined, color: Colors.white), SizedBox(width: 8), Text('Agent 编排引擎 · LangGraph', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))]),
                const SizedBox(height: 8),
                const Text('感知 → 规划 → 记忆 → 工具 → 执行。每个 Agent 都能读取你的价值云与负债画像，并通过 50+ 工具调用真实业务接口。', style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip('多模型路由'),
                  _chip('RAG 法规库'),
                  _chip('Fact Card 长期记忆'),
                  _chip('输出侧合规审核'),
                  _chip('Prompt 注入检测'),
                ]),
              ],
            ),
          ),
          const SectionTitle('8 大核心 Agent'),
          ...AgentService.agents.map((a) {
            final hist = AgentService.instance.history(s.me.userId, a.code);
            return XCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              onTap: () => openAgent(context, a.code),
              child: Row(
                children: [
                  GradientAvatar(a, size: 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(width: 6),
                          Text(a.code, style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                          const Spacer(),
                          Tag(a.model, color: XgColors.agentGradient(a.gradientIndex).first),
                        ]),
                        const SizedBox(height: 4),
                        Text(a.role, style: const TextStyle(fontSize: 12, color: XgColors.textSecondary)),
                        if (hist.length > 1) ...[
                          const SizedBox(height: 4),
                          Text('${hist.length - 1} 条对话记录', style: const TextStyle(fontSize: 10, color: XgColors.info)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SectionTitle('多模型路由决策矩阵 · AI-303'),
          XCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: const [
                _RouteRow('复杂推理（还款规划）', 'GPT-4o', 'Claude 3.5 / DeepSeek-V3'),
                _RouteRow('长文本情感陪伴', 'Claude 3.5 Sonnet', 'GPT-4o'),
                _RouteRow('中文创作 / 直播话术', 'Qwen-Max', 'GLM-4 / DeepSeek'),
                _RouteRow('法律条款解读', 'Baichuan-Legal', 'GPT-4o + RAG'),
                _RouteRow('高频短对话（客服）', 'DeepSeek-V3', 'GLM-4-Flash'),
                _RouteRow('敏感金融数据', '私有 Qwen-72B', '私有 GLM-4-9B'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11)),
  );
}

class _RouteRow extends StatelessWidget {
  final String scene, primary, backup;
  const _RouteRow(this.scene, this.primary, this.backup);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(flex: 5, child: Text(scene, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 4, child: Text(primary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: XgColors.navy))),
        Expanded(flex: 4, child: Text(backup, style: const TextStyle(fontSize: 10, color: XgColors.textSecondary))),
      ]),
    );
  }
}

class AgentChatPage extends StatefulWidget {
  final String agentCode;
  const AgentChatPage({super.key, required this.agentCode});
  @override
  State<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends State<AgentChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  late AgentDef agent;
  late List<ChatMessage> msgs;

  @override
  void initState() {
    super.initState();
    agent = AgentService.byCode(widget.agentCode);
    msgs = AgentService.instance.history(context.read<AppState>().me.userId, widget.agentCode);
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _busy) return;
    final s = context.read<AppState>();
    _ctrl.clear();
    // API-AI-001 感知层：意图分类 + 敏感词 + 注入检测
    final r = await s.call('POST', '/v1/ai/agents/${agent.code}/stream', apiId: 'API-AI-002', body: {'message': text, 'conv_id': '${s.me.userId}:${agent.code}'});
    if (!mounted) return;
    if (!r.ok) {
      showApiResult(context, r);
      return;
    }
    setState(() {
      _busy = true;
      msgs.add(ChatMessage(id: 'u${msgs.length}', fromUser: true, text: text, at: DateTime.now()));
    });
    final tools = AgentService.instance.toolsFor(agent.code, text);
    final bot = ChatMessage(id: 'a${msgs.length}', fromUser: false, text: '', at: DateTime.now(), model: agent.model, toolCalls: tools, streaming: true);
    setState(() => msgs.add(bot));
    _jump();
    await Future.delayed(const Duration(milliseconds: 600)); // 首字延迟 ≤ 1.5s
    await for (final chunk in AgentService.instance.stream(s.me.userId, agent.code, text)) {
      if (!mounted) return;
      setState(() => bot.text = chunk);
      _jump();
    }
    if (mounted) {
      setState(() {
        bot.streaming = false;
        _busy = false;
      });
    }
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = XgColors.agentGradient(agent.gradientIndex);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          GradientAvatar(agent, size: 32),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(agent.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('${agent.enName} · ${agent.model}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
        ]),
        actions: [
          IconButton(
            tooltip: '删除会话 API-AI-004',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () {
              AgentService.instance.clear(context.read<AppState>().me.userId, agent.code);
              setState(() => msgs = AgentService.instance.history(context.read<AppState>().me.userId, agent.code));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: g.first.withValues(alpha: 0.08),
            child: Row(children: [
              Icon(Icons.memory, size: 13, color: g.first),
              const SizedBox(width: 6),
              Expanded(child: Text('记忆：短期 20 轮 · Fact Card 已加载（负债/职业/偏好） · 输出侧合规审核开启', style: TextStyle(fontSize: 10, color: g.first))),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: msgs.length + 1,
              itemBuilder: (_, i) {
                if (i == msgs.length) {
                  if (msgs.length > 1 || _busy) return const SizedBox(height: 8);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: agent.quickPrompts.map((q) => ActionChip(label: Text(q, style: const TextStyle(fontSize: 12)), onPressed: () => _send(q), backgroundColor: Colors.white, side: BorderSide(color: g.first.withValues(alpha: 0.4)))).toList(),
                    ),
                  );
                }
                final m = msgs[i];
                return _Bubble(m: m, agent: agent, onFeedback: (v) async {
                  setState(() => m.feedback = v);
                  final r = await context.read<AppState>().call('POST', '/v1/ai/feedback', apiId: 'API-AI-005', body: {'message_id': m.id, 'score': v});
                  if (context.mounted) showApiResult(context, r, successText: v > 0 ? '感谢反馈 · 已进入 Prompt 迭代闭环' : '已记录 · 触发幻觉检测复核');
                });
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: XgColors.divider))),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: _send,
                    decoration: InputDecoration(hintText: '对 ${agent.name} 说点什么…', fillColor: XgColors.bg),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: g), borderRadius: BorderRadius.circular(12)),
                  child: IconButton(icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_upward, color: Colors.white), onPressed: _busy ? null : () => _send(_ctrl.text)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final AgentDef agent;
  final ValueChanged<int> onFeedback;
  const _Bubble({required this.m, required this.agent, required this.onFeedback});
  @override
  Widget build(BuildContext context) {
    final g = XgColors.agentGradient(agent.gradientIndex);
    if (m.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(color: XgColors.navy, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4))),
          child: Text(m.text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientAvatar(agent, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.toolCalls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(spacing: 4, runSpacing: 4, children: m.toolCalls.map((t) => Tag('🔧 $t', color: g.first, bg: g.first.withValues(alpha: 0.08))).toList()),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)), border: Border.all(color: XgColors.divider)),
                  child: m.text.isEmpty
                      ? Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: g.first)), const SizedBox(width: 8), const Text('规划中…', style: TextStyle(fontSize: 12, color: XgColors.textSecondary))])
                      : SelectableText(m.text + (m.streaming ? ' ▍' : ''), style: const TextStyle(fontSize: 14, height: 1.5)),
                ),
                if (!m.streaming && m.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Row(children: [
                      Text(m.model ?? '', style: const TextStyle(fontSize: 10, color: XgColors.textSecondary)),
                      const SizedBox(width: 8),
                      if (m.id != 'm0') ...[
                        InkWell(onTap: () => onFeedback(1), child: Icon(m.feedback == 1 ? Icons.thumb_up : Icons.thumb_up_outlined, size: 14, color: m.feedback == 1 ? XgColors.success : XgColors.textSecondary)),
                        const SizedBox(width: 10),
                        InkWell(onTap: () => onFeedback(-1), child: Icon(m.feedback == -1 ? Icons.thumb_down : Icons.thumb_down_outlined, size: 14, color: m.feedback == -1 ? XgColors.danger : XgColors.textSecondary)),
                      ],
                    ]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
