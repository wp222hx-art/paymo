import 'dart:async';
import 'dart:math';

import '../models/models.dart';
import 'mock_db.dart';

/// AI 智能域：8 大 Agent 定义 + 模拟 LangGraph 编排（感知→规划→记忆→工具→执行）
class AgentService {
  AgentService._();
  static final AgentService instance = AgentService._();

  static const agents = <AgentDef>[
    AgentDef(code: 'AG-01', name: '债务规划师', enName: 'DebtPlanner', role: '根据负债画像生成 12/24/36 月还款路径', model: 'GPT-4o', gradientIndex: 0, emoji: '🧭', greeting: '你好，我是你的债务规划师。我已读取你的负债画像，可以随时为你生成停息挂账、分期或一次性结清方案。想从哪一笔债务开始？', quickPrompts: ['帮我规划招行信用卡的还款', '我每月能还多少比较安全？', '一次性结清能打几折？']),
    AgentDef(code: 'AG-02', name: '赋能教练', enName: 'EmpowerCoach', role: '情绪疏导 + 目标设定 + 每日打卡陪伴', model: 'Claude 3.5 Sonnet', gradientIndex: 1, emoji: '🌱', greeting: '嗨，今天感觉怎么样？不用急着回答"还好"。你已经连续来了 23 天，这本身就是一件很了不起的事。', quickPrompts: ['我今天很焦虑', '帮我定今天的小目标', '我想放弃了']),
    AgentDef(code: 'AG-03', name: '接单助手', enName: 'TaskMatcher', role: '根据能力标签自动匹配任务并生成投递话术', model: 'Qwen-Max', gradientIndex: 2, emoji: '🎯', greeting: '我是接单助手。基于你的价值云能力标签，我已为你筛出匹配度最高的任务。要我生成投递话术吗？', quickPrompts: ['今天有什么适合我的任务？', '帮我写一段投递自荐', '我的能力标签准确吗？']),
    AgentDef(code: 'AG-04', name: '创作助手', enName: 'ContentCreator', role: '生成短视频脚本 / 图文 / 直播话术 / 商品文案', model: 'GPT-4o + 视频模型', gradientIndex: 3, emoji: '✨', greeting: '创作助手就位。告诉我主题，我可以输出 30 秒短视频脚本、小红书图文或直播话术，并自动标注 AI 生成比例。', quickPrompts: ['写一个还债经历短视频脚本', '帮我写护肤品种草文案', '直播开场话术']),
    AgentDef(code: 'AG-05', name: '谈判专家', enName: 'Negotiator', role: '协助与银行/AMC 谈判，起草协商方案函', model: 'Claude 3.5 + Legal-tuned', gradientIndex: 4, emoji: '🤝', greeting: '我是谈判专家。协商的核心是"专业而非哀求"。我可以帮你起草停息挂账申请函、整理还款能力证明。', quickPrompts: ['起草停息挂账申请函', '银行拒绝协商怎么办', '如何证明还款能力']),
    AgentDef(code: 'AG-06', name: '法务顾问', enName: 'LegalAdvisor', role: '解读征信、催收合法性、诉讼应对；律师人工兜底', model: 'Baichuan-Legal + RAG', gradientIndex: 5, emoji: '⚖️', greeting: '法务顾问在线。我基于《催收自律公约》《民法典》等知识库回答，复杂问题会转接合作律师。', quickPrompts: ['催收打给我父母合法吗？', '收到律师函怎么办', '逾期多久会被起诉']),
    AgentDef(code: 'AG-07', name: '商业分身', enName: 'BusinessAvatar', role: '24×7 代运营账号 / 私域回复 / 商品挂单', model: 'Qwen-Max + 私域微调', gradientIndex: 6, emoji: '🪞', greeting: '我是你的商业分身，昨夜为你回复了 37 条私域消息，挂单 2 件商品。要看今日代运营日报吗？', quickPrompts: ['今日代运营日报', '帮我回复粉丝私信', '自动挂单设置']),
    AgentDef(code: 'AG-08', name: '监管哨兵', enName: 'ComplianceWatcher', role: '内部合规巡查，识别违规话术/内容/交易', model: 'GLM-4 + 规则引擎', gradientIndex: 7, emoji: '🛡️', greeting: '监管哨兵巡查中。近 24h 拦截违规内容 58 条、可疑交易 3 笔。你可以向我咨询任何合规边界问题。', quickPrompts: ['今日合规巡查报告', '这段话术合规吗？', 'AIGC 标注要求']),
  ];

  static AgentDef byCode(String c) => agents.firstWhere((a) => a.code == c);

  final Map<String, List<ChatMessage>> _conversations = {};
  final _rand = Random(7);

  List<ChatMessage> history(String userId, String agentCode) {
    final key = '$userId:$agentCode';
    return _conversations.putIfAbsent(key, () {
      final a = byCode(agentCode);
      return [ChatMessage(id: 'm0', fromUser: false, text: a.greeting, at: DateTime.now(), model: a.model)];
    });
  }

  void clear(String userId, String agentCode) => _conversations.remove('$userId:$agentCode');

  /// 流式返回：模拟 SSE 逐字输出
  Stream<String> stream(String userId, String agentCode, String input) async* {
    final u = MockDb.instance.users[userId]!;
    final reply = _plan(agentCode, input, u);
    final chunks = reply.split('');
    final buf = StringBuffer();
    for (int i = 0; i < chunks.length; i++) {
      buf.write(chunks[i]);
      if (i % 3 == 0) {
        await Future.delayed(Duration(milliseconds: 12 + _rand.nextInt(20)));
        yield buf.toString();
      }
    }
    yield buf.toString();
  }

  List<String> toolsFor(String agentCode, String input) {
    switch (agentCode) {
      case 'AG-01':
        return ['query_debt_cases', 'query_debt_profile', 'apr_compliance_check', 'generate_plan'];
      case 'AG-02':
        return ['read_emotion_timeline', 'get_checkin_streak'];
      case 'AG-03':
        return ['query_value_cloud', 'search_tasks', 'rank_by_embedding'];
      case 'AG-04':
        return ['fetch_brand_brief', 'aigc_label'];
      case 'AG-05':
        return ['query_debt_case', 'draft_letter', 'e_sign_prepare'];
      case 'AG-06':
        return ['rag_query(法规库)', 'lawyer_handoff_check'];
      case 'AG-07':
        return ['fetch_dm_inbox', 'list_products'];
      default:
        return ['risk_rule_engine', 'moderation_check'];
    }
  }

  String _plan(String code, String input, UserProfile u) {
    final db = MockDb.instance;
    final dp = db.debtProfiles[u.userId];
    final cases = db.debtCases.where((c) => c.userId == u.userId).toList();
    switch (code) {
      case 'AG-01':
        if (dp == null || cases.isEmpty) {
          return '我注意到你的账号（${u.role.label}）还没有负债档案。如果你是替他人咨询，可以先在「我的 → 债务档案」手动录入一笔债务，我就能给出具体路径。\n\n通用原则：\n1. 优先处理逾期 > 90 天（M3+）且罚息增长最快的一笔；\n2. 月供总额控制在月收入 45% 以内；\n3. 任何方案都要经 LPR×4 利率合规校验。';
        }
        final worst = cases.reduce((a, b) => a.overdueDays >= b.overdueDays ? a : b);
        final safe = dp.monthlyIncome * 0.45;
        return '【调用工具】query_debt_cases ✓ · query_debt_profile ✓ · apr_compliance_check ✓\n\n'
            '📊 你的全景：${cases.length} 笔债务，总待还 ¥${_fmt(dp.totalDebt)}，最长逾期 ${dp.overdueDaysMax} 天，还款意愿分 ${dp.repaymentWillingness}，还款能力分 ${dp.repaymentAbility}。\n\n'
            '🎯 优先级建议：先处理「${worst.creditorName}」（${worst.bucket} 桶，待还 ¥${_fmt(worst.outstanding)}），这笔罚息增速最快。\n\n'
            '💡 三条路径（月收入 ¥${_fmt(dp.monthlyIncome)}，安全月供上限 ¥${_fmt(safe)}）：\n'
            '① 稳健 · 36 期停息挂账：月供 ≈ ¥${_fmt((worst.outstanding - worst.penalty) / 36)}，压力最低；\n'
            '② 进取 · 24 期 + 流量还债 60%：月供 ≈ ¥${_fmt(worst.outstanding / 24)}，配合任务收益可提前 5~7 期；\n'
            '③ 决断 · 一次性结清本金 8 折：需筹 ¥${_fmt(worst.principal * 0.8)}。\n\n'
            '要我在「债务档案 → ${worst.creditorName}」里正式生成这三套方案供你确认吗？（会调用 API-R-005）';
      case 'AG-02':
        if (RegExp(r'焦虑|难受|失眠|害怕|崩').hasMatch(input)) {
          return '我听到了。焦虑不是软弱，它是你的身体在提醒你"这件事对我很重要"。\n\n先做一件事：把手机放远一点，深呼吸 4 秒、屏住 4 秒、呼出 6 秒，做三轮。\n\n然后我们只看一个事实——你的赎回进度已经 ${u.redeemProgressPct.toStringAsFixed(1)}%，累计化解 ¥${_fmt(u.carbonDebtSaved)}。这是过去的你一点点做出来的。今晚不需要解决所有问题，只需要睡好。\n\n我明早 8 点会来找你打卡。🌱';
        }
        if (RegExp(r'放弃|不想|算了').hasMatch(input)) {
          return '想放弃的念头很正常，尤其在坚持了这么久之后。我不会劝你"加油"。\n\n但我想让你看一眼：连续打卡 23 天、完成 ${db.orders.where((o) => o.userId == u.userId && o.status == 80).length} 个任务、光芒值 ${u.lightPoints}。这些数字不会因为今天想放弃就消失。\n\n要不要今天就只做一件最小的事：打开任务市场看 1 分钟，不接单也行。做完告诉我。';
        }
        return '今天的小目标我帮你拆好了：\n\n☐ 09:00 查看债务规划师给的方案（5 分钟）\n☐ 14:00 完成任务 TO5001 的 2 小时客服排班\n☐ 21:00 记录一句今日心情\n\n完成任意一项都算打卡成功。等级 Lv.${u.level}，再 ${u.level * 400 - u.exp} 经验升级。我陪你。';
      case 'AG-03':
        final tags = u.capabilityTags.toSet();
        final ranked = db.tasks.where((t) => t.status == 2).map((t) => (t, t.targetTags.where(tags.contains).length)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
        final top = ranked.take(3).toList();
        final sb = StringBuffer('【调用工具】query_value_cloud ✓ · rank_by_embedding ✓\n\n基于你的能力标签「${u.capabilityTags.take(3).join(' / ')}」，Top-3 匹配：\n\n');
        for (var i = 0; i < top.length; i++) {
          final t = top[i].$1;
          sb.writeln('${i + 1}. ${t.title}\n   ¥${_fmt(t.rewardAmount)} · ${t.splitPolicy.label} · 匹配度 ${88 - i * 7 + top[i].$2 * 3}%\n   门槛：${KycLevel.name(t.kycLevelRequired)} / 价值分 ≥ ${t.valueScoreMin}${u.valueScore < t.valueScoreMin ? '（⚠️ 你当前 ${u.valueScore.toStringAsFixed(0)}）' : ' ✓'}\n');
        }
        if (RegExp(r'话术|自荐|投递').hasMatch(input)) {
          sb.write('\n📝 投递话术草稿：\n"您好，我是${u.nickname}，${u.occupation}出身，擅长${u.capabilityTags.take(2).join('与')}。平台履约分 ${u.creditScore}，已完成任务 ${db.orders.where((o) => o.userId == u.userId && o.status == 80).length} 个，可在 48h 内交付初稿。"');
        } else {
          sb.write('\n去「任务」页一键接单，或让我生成投递话术。');
        }
        return sb.toString();
      case 'AG-04':
        if (RegExp(r'护肤|种草|文案').hasMatch(input)) {
          return '【AIGC 标注：本文案 100% AI 生成，发布时将自动标注】\n\n🌟 小红书文案 · 星辰晨露精华\n\n标题：敏感肌熬夜党，我终于找到早 C 晚 A 的温和平替了\n\n正文：\n负债那年我连护肤都在省，但皮肤状态差到面试都没底气。\n后来接到这个种草任务，抱着"反正是任务"的心态试了两周——\n✔ 上脸不刺痛（敏感肌真的怕这个）\n✔ 早上用完不搓泥，妆前很服帖\n✔ 一瓶 ¥129，比我之前买的大牌少一个 0\n\n最重要的是，这条笔记的收益 60% 会直接还进我的信用卡。\n所以如果你也在"省钱但想变好"的路上，这瓶可以试试。\n\n#国货护肤 #敏感肌 #流量还债\n\n—— 需要我改成 30 秒竖版视频脚本吗？';
        }
        return '【AIGC 标注：本脚本 100% AI 生成】\n\n🎬 30 秒竖版短视频脚本 · 《我的第一笔流量还债》\n\n0-3s｜黑屏白字："负债 ${dp != null ? _fmt(dp.totalDebt) : '13 万'}那天，我删掉了所有社交软件。"\n3-10s｜真人出镜，手机屏幕特写：新光云 App 任务市场，手指点下「接单」。\n10-20s｜快切 3 个镜头：剪视频 / 深夜改稿 / 提交交付物。字幕："AI 初验通过 · 商家验收通过"\n20-27s｜结算页面：¥380 → 60% 自动划入招行还款。画外音："这是第一笔不是我掏钱、而是我赚回来的还款。"\n27-30s｜进度环从 41.2% → 42.6%。字幕："每一分努力，都在照亮未来。"\n\nBGM 建议：轻钢琴 → 渐强\n#真实经历 #流量还债';
      case 'AG-05':
        final target = cases.where((c) => c.negotiationStatus < 2).firstOrNull ?? cases.firstOrNull;
        if (target == null) return '你当前没有可协商的债务案件。如果是替他人咨询：协商函三段式——现状陈述（不卖惨）、还款能力证明（流水+收入）、诚意方案（具体期数和金额）。';
        return '【调用工具】query_debt_case(${target.caseId}) ✓ · draft_letter ✓\n\n📄 个性化分期还款协商申请函（草稿）\n\n致 ${target.creditorName}：\n\n本人${u.nickname}，持有贵行账户（案件编号 ${target.caseNo}），因${u.occupation.contains('餐饮') ? '经营的餐饮门店受市场环境影响歇业' : '收入中断'}，导致自 ${target.overdueDays} 天前起未能按期还款，目前待还 ¥${_fmt(target.outstanding)}。\n\n本人从未回避债务，现已通过新光云平台建立稳定收入来源（近 3 个月月均收入 ¥${dp != null ? _fmt(dp.monthlyIncome) : '—'}，可提供流水），并承诺将平台流量收益的 60% 自动划入还款。\n\n恳请贵行依据《商业银行信用卡业务监督管理办法》第七十条，予以个性化分期协商：停止计收罚息，将剩余本息分 36 期偿还，每期 ¥${_fmt((target.outstanding - target.penalty) / 36)}。\n\n附件：收入证明 / 平台履约记录 / 还款能力评估报告\n\n此致\n${u.nickname}  2026 年 9 月 11 日\n\n——\n💡 谈判要点：① 语气专业而非哀求；② 主动给方案而非等对方开价；③ 提及监管依据。需要我通过 e签宝 生成正式 PDF 吗？';
      case 'AG-06':
        if (RegExp(r'父母|家人|第三|单位|同事').hasMatch(input)) {
          return '【RAG 检索】《互联网金融贷后催收风控指引》§3.4 · 《个人信息保护法》§10 · 相似度 0.91\n\n⚖️ 结论：不合法，除非该第三人是你的紧急联系人且仅用于"联系不上你本人"的告知。\n\n具体边界：\n1. 催收不得向无关第三人透露你的债务信息（属个人敏感信息）；\n2. 即便是紧急联系人，也只能询问联系方式，不得施压或要求代偿；\n3. 催收时段限 08:00~20:00，单日联系频次受限；\n4. 威胁、侮辱、骚扰均可投诉至银保监 12378 / 互金协会。\n\n📌 建议动作：\n· 立即录音留证（通话 + 短信截图）；\n· 在本平台「合规 → 投诉举报」提交，我们会协助出具《催收行为异议函》；\n· 如情节严重，可转接合作律师（免费首咨）。\n\n⚠️ 本回复为 AI 基于法规知识库生成，不构成正式法律意见。';
        }
        return '【RAG 检索】民法典 §675 · 民诉法 §122 · 相似度 0.87\n\n⚖️ 逾期与诉讼的一般规律：\n· 信用卡逾期 3 个月且金额 ≥ 5 万，银行可能报案（刑法 §196 需"恶意透支"要件——你有还款行为即不构成）；\n· 民事起诉无固定时限，但通常在 M6+ 且协商无果后；\n· 收到律师函 ≠ 被起诉，律师函是施压手段，请核实律所真实性。\n\n📌 你现在最有力的自我保护：保持协商记录 + 部分还款流水。这两样在任何司法程序中都是"非恶意"的关键证据。\n\n需要我把这段整理成《应对催收与诉讼备忘》PDF 吗？\n\n⚠️ AI 生成，复杂个案请转接律师。';
      case 'AG-07':
        return '【调用工具】fetch_dm_inbox ✓ · list_products ✓\n\n🪞 商业分身 · 昨夜代运营日报（09-10 22:00 → 09-11 08:00）\n\n📨 私域回复 37 条\n· 咨询「怎么开始流量还债」×14 → 已发送新手指南 + 你的邀请码 ${u.inviteCode}\n· 询问商品 ×9 → 引导至挂单商品页\n· 情绪求助 ×3 → 已转交赋能教练并标记跟进\n· 疑似引流广告 ×2 → 已拦截并上报监管哨兵\n\n🛒 自动挂单 2 件\n· 《债务协商函模板包》光芒值 300 · 昨夜售出 4 份\n· 《餐饮门店线上运营 SOP》¥49 · 售出 1 份\n\n📈 带来新增关注 +86，预计本周流量还债 +¥210。\n\n要我调整回复风格（更亲切 / 更专业），或者关闭夜间自动挂单吗？';
      default:
        if (RegExp(r'合规|话术|可以说|能不能').hasMatch(input) && input.length > 12) {
          final bad = RegExp(r'征信修复|内部渠道|包过|百分百|消除逾期|加微').hasMatch(input);
          return bad
              ? '🛡️ 判定：❌ 不合规（命中规则 CNT-INDUCE-003，风险分 96）\n\n问题点：\n· "征信修复 / 内部渠道 / 消除逾期"属虚假宣传 + 金融违规诱导；\n· 引流联系方式违反平台反引流规则。\n\n如发布将被 AI 初审直接拦截，并生成风控案件。\n\n✅ 合规改写建议："逾期记录在结清后 5 年自动消除，没有任何机构能提前删除。想了解正规协商流程可以看我的置顶。"'
              : '🛡️ 判定：✅ 基本合规（风险分 18）\n\n提示：涉及金融/负债类目内容会进入人工复审队列（SLA ≤ 30 min），建议：\n· 如使用 AI 辅助请勾选「AI 生成」标注；\n· 避免绝对化用词（"一定""百分百"）。';
        }
        return '🛡️ 监管哨兵 · 24h 合规巡查报告\n\n内容侧\n· AI 初审 4,812 条，拦截 58 条（1.2%），主类目：引流联系方式 31 / 征信修复话术 19 / AIGC 未标注 8\n· 人工复审队列积压 ${MockDb.instance.contents.where((c) => c.moderationStatus == 0).length} 条，均在 SLA 内\n\n交易侧\n· AML 可疑交易 3 笔，1 笔已升级 EDD 尽调（RC8005）\n· 大额提现拦截 2 笔，均转人工电话核实\n\nAI 侧\n· Prompt 注入尝试 126 次，全部拦截；灰度规则 AI-INJECT-007 误报率 21%，建议调高阈值至 0.85\n\n合规待办\n· 反洗钱 T+3 报送：明日 09:00 截止 ✓ 已生成\n· 隐私政策 v3.2 需重新征询 Consent 用户 1,204 人\n\n需要我导出报告给合规专员吗？';
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}
