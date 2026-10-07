import 'package:flutter/material.dart';

import 'theme.dart';

/// 模块说明注册表：每个页面的"专业信息卡"文案（对应技术蓝图编号）
class ModuleInfo {
  final String code; // 蓝图编号
  final String title;
  final String tagline;
  final String description;
  final List<String> highlights; // 关键能力
  final List<String> apis; // 相关接口
  final IconData icon;
  final Color color;
  const ModuleInfo({
    required this.code,
    required this.title,
    required this.tagline,
    required this.description,
    required this.highlights,
    required this.apis,
    required this.icon,
    this.color = XgColors.navy,
  });
}

class Modules {
  static const home = ModuleInfo(
    code: 'D01 · U-104',
    title: '赎回驾驶舱',
    tagline: '一眼看清：还了多少、还剩多少、今天能做什么',
    description: '首页聚合负债画像、赎回进度、债务积分池与 AI 教练建议。所有数字均来自真实业务流（复式账本 + 银行核销回执），不是估算。',
    highlights: ['赎回进度 = 累计化解 / 初始总负债', '债务积分实时可用余额与现金背书率', 'AI 派单 Top-3 · 基于价值云 Embedding 匹配'],
    apis: ['GET /v1/users/me', 'GET /v1/users/me/debt-profile', 'GET /v1/debt-points'],
    icon: Icons.home_outlined,
  );

  static const debtPoints = ModuleInfo(
    code: 'R-604 · R-605 · 核心闭环',
    title: '债务积分 · 银行清缴',
    tagline: '平台所有价值创造 → 统一积分 → 银行核销 → 结清证明',
    description: '债务积分（DP）是平台唯一的平债结算语言，1 DP = ¥1 抵扣面值。每批积分记录现金背书（平台真实持有并汇给银行的资金）；差额为银行基于你的履约数据接受的协商减免。',
    highlights: ['四大来源：任务结算 / 内容收益 / 消费平债 / 光芒值兑换', '转交银行后由清收专员受理 → 确认收款 → 核销', '案件余额归零 → 银行出具《债务结清证明》（SM2 签章）', 'FIFO 批次消耗，退回可精确回滚'],
    apis: ['GET /v1/debt-points', 'POST /v1/clearance/submit', 'Webhook CLEARANCE.* / CERTIFICATE.ISSUED'],
    icon: Icons.token_outlined,
    color: XgColors.goldDark,
  );

  static const shop = ModuleInfo(
    code: 'D07 · S-701 ~ S-708',
    title: '本地生活 · 消费平债',
    tagline: '该花的钱照花，平台利润替你还债',
    description: '电影、餐饮、出行、缴费、生鲜、教育……日常消费走平台，平台分到的利润按倍率转化为债务积分并自动计入。商家不少赚、你不多花、平台让利、银行回款——四方共赢。',
    highlights: ['抵债 DP = 平台利润 × min(品类基础倍率 + 信用加成, 全局上限)', '信用重塑分越高，同样消费抵债越多', '每笔订单生成 3 条复式分录，利润进「债务积分现金备付金」', '倍率规则由运营配置，下单落规则快照可审计'],
    apis: ['GET /v1/shop/products', 'POST /v1/shop/quote', 'POST /v1/shop/orders'],
    icon: Icons.storefront_outlined,
    color: XgColors.coral,
  );

  static const debtCenter = ModuleInfo(
    code: 'D06 · R-601 ~ R-603',
    title: '债务中心',
    tagline: '把所有债务摊在阳光下，才能一笔一笔解决',
    description: '接入央行征信 / 银行 / AMC 形成债务全景；AI 债务规划师基于月收入与逾期分桶生成稳健 / 进取 / 决断三套方案，经 LPR×4 利率合规校验后供你确认。',
    highlights: ['两条平债通道：还款计划（现金直付）+ 债务积分（银行核销）', '多头借贷指数 / 还款意愿分 / 还款能力分 三维画像', '方案确认即触发 e签宝电子协议与债权方 Webhook', '每周快照绘制赎回轨迹'],
    apis: ['POST /v1/debt-cases/import/*', 'POST /v1/repayment-plans/ai/generate', 'POST /v1/repayment-plans/{id}/confirm|execute'],
    icon: Icons.account_balance_outlined,
  );

  static const wallet = ModuleInfo(
    code: 'R-603 · R-604 · R-607',
    title: '钱包 · 资金账户',
    tagline: '每一分钱的来龙去脉都可追溯',
    description: '银行存管 II 类账户，充值 / 提现 / 任务收益 / 内容收益统一流水。所有资金变动生成复式借贷分录，账本只增不改，每日自动跑借贷平衡校验。',
    highlights: ['KYC 等级决定单日限额（L2 ¥500 → L5 ¥50 万）', '大额提现 + 中风险 → 转人工电话核实 T+1', '光芒值 100 ✦ = 1 DP，进入积分池', '支付密码 5 分钟令牌保护敏感操作'],
    apis: ['GET /v1/wallets/me', 'POST /v1/wallets/recharge|withdraw', 'GET /v1/wallets/transactions'],
    icon: Icons.account_balance_wallet_outlined,
  );

  static const tasks = ModuleInfo(
    code: 'D05 · T-501 ~ T-508',
    title: '任务与流量',
    tagline: '用你的能力赚钱，收益按你设定的比例自动还债',
    description: '品牌方 / 商家发布任务并缴纳保证金；AI 接单助手按价值云匹配；交付后 AI 初验（原创性 / 搬运检测）→ 商家验收 → 自动分账。还债部分发行为债务积分。',
    highlights: ['订单状态机 10→20→40→50→60→80，争议 / 超时分支完整', 'AI 初验 < 60 分退回，最多 3 次', '商家 72h 未响应自动通过', '分账策略：现金 / 还债 / 平台费 三方可配'],
    apis: ['GET /v1/tasks/market', 'POST /v1/tasks/{id}/accept', 'POST /v1/tasks/{id}/orders/{oid}/submit|review'],
    icon: Icons.work_outline,
    color: XgColors.info,
  );

  static const agents = ModuleInfo(
    code: 'D03 · AI-301 ~ AI-310',
    title: 'AI 智能域',
    tagline: '8 位陪伴者，感知 → 规划 → 记忆 → 工具 → 执行',
    description: 'LangGraph 编排的 Multi-Agent 体系。每个 Agent 都能读取你的价值云与负债画像，通过 50+ 工具调用真实业务接口；多模型路由按场景 / 成本 / 合规选型；输出侧合规审核与 Prompt 注入检测常开。',
    highlights: ['债务规划师 GPT-4o · 赋能教练 Claude 3.5 · 法务顾问 Baichuan-Legal + RAG', '短期 20 轮 + Fact Card 长期记忆', '点赞 / 点踩进入 Prompt 迭代闭环', '敏感金融数据走私有部署 Qwen-72B 不出域'],
    apis: ['POST /v1/ai/agents/{code}/stream', 'POST /v1/ai/feedback', 'POST /v1/ai/rag/query'],
    icon: Icons.auto_awesome_outlined,
    color: XgColors.violet,
  );

  static const community = ModuleInfo(
    code: 'D04 · D08',
    title: '内容与社区',
    tagline: '真实经历是最有力量的内容，也是最稳的收益',
    description: '图文 / 短视频 / 音频创作，三审制（AI 初审 12 维度 → 人工复审 → 抽检）保障合规；推荐流 = 协同过滤 + Embedding 相似。内容收益的还债部分自动发行债务积分。',
    highlights: ['AIGC 必须标注（合规硬要求）', '分享生成 UTM 归因短链，点击 7d / 转化 30d', '互助社群：债务同盟 / 心灵驿站 / 共学计划', '催收合规 / 征信修复类话术 AI 直接拦截'],
    apis: ['POST /v1/contents', 'GET /v1/contents/feed/*', 'POST /v1/contents/{id}/like|share|report'],
    icon: Icons.forum_outlined,
  );

  static const profile = ModuleInfo(
    code: 'D01 · D02 · U-106 · U-107',
    title: '我的 · 身份与安全',
    tagline: 'KYC 五级、权限点、隐私开关，一切可控',
    description: 'KYC L0~L5 逐级解锁功能与限额；RBAC + ABAC 双层权限；字段级隐私开关、数据可携权、被遗忘权（15 日冷静期）。',
    highlights: ['L2 公安三要素 · L3 活体 · L4 银行卡四要素 · L5 企业', '设备指纹绑定，异地 / 新设备二次验证', '敏感字段 SM4 加密、脱敏返回', '注销 15 日可撤销，业务凭证保留 5 年'],
    apis: ['POST /v1/auth/kyc/l2|l3|l4', 'GET /v1/auth/sessions', 'PATCH /v1/users/me/privacy'],
    icon: Icons.person_outline,
  );

  static const bankQueue = ModuleInfo(
    code: '开放平台 · Kong-Open · R-605',
    title: '债权方工作台',
    tagline: '受理 → 确认收款 → 核销 → 签发结清证明',
    description: '银行 / AMC 通过开放平台（AppKey + HMAC-SHA256 签名）接入。清收专员人工受理用户转交的债务积分，核对平台存管汇款后按面值核销，可选择是否接受协商减免。',
    highlights: ['数据按机构租户隔离（ABAC）', '批量核销：原子事务，任一笔不合法整批回滚', '退回自动回滚积分并红字冲销备付金', '案件归零后签发《债务结清证明》，Webhook 回推平台'],
    apis: ['POST /v1/bank/clearances/{id}/accept|confirm-remit|write-off|reject', 'POST /v1/bank/clearances/batch-write-off', 'POST /v1/bank/recon'],
    icon: Icons.account_balance,
    color: XgColors.success,
  );

  static const risk = ModuleInfo(
    code: 'M02 · RC-201 ~ RC-208',
    title: '风控管理',
    tagline: '四级风险、规则引擎、案件闭环',
    description: '注册 / 登录 / 交易 / 内容 / 提现 九大校验节点；Drools DSL 规则可视化配置、灰度与 AB；命中生成案件进入人工处置，所有处置写入 WORM 审计。',
    highlights: ['L1 日志提醒 → L2 二次验证 → L3 冻结 → L4 封禁上报', 'AML 大额快进快出 / 可疑交易 STR', '误报率回填驱动规则迭代', '处置结果实时影响用户状态机'],
    apis: ['POST /v1/admin/risk/cases/{id}/dispose', 'PUT /v1/admin/risk/rules/{code}'],
    icon: Icons.shield_outlined,
    color: XgColors.danger,
  );

  static const ops = ModuleInfo(
    code: 'M01 · OP-101 ~ OP-108',
    title: '运营看板',
    tagline: '北极星：月度赎回进度总额',
    description: '实时大盘覆盖用户 / 内容 / 任务 / 还债 / 商城 / AI / 资金 / 合规 九层指标；三审制人工复审队列；任务审核；平债倍率规则引擎。',
    highlights: ['北极星指标实时随银行核销回执变化', 'AI 指标：调用量 / Token 成本 / 首字延迟 P99 / 满意度', '倍率规则：品类基础 + 信用加成 + 全局上限', '生产规则改值自动降灰度，发布需审批'],
    apis: ['GET /v1/admin/dashboard', 'POST /v1/admin/moderation/{id}', 'PUT /v1/admin/offset-rules/{id}'],
    icon: Icons.dashboard_outlined,
  );
}
