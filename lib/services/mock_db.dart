import '../models/models.dart';

/// 内存态"数据库"：模拟 PostgreSQL / TiDB / MongoDB 的持久层。
/// 多用户共享同一份数据，切换用户时按 userId 过滤。
class MockDb {
  MockDb._();
  static final MockDb instance = MockDb._();

  int _seq = 1000;
  String nextId(String prefix) => '$prefix${++_seq}';

  final now = DateTime(2026, 9, 11, 9, 30);

  // ───── 用户 ─────
  late final Map<String, UserProfile> users = {
    'U1001': UserProfile(
      userId: 'U1001',
      uuid: 'a3f9c2e1b7d84e0f9c1a2b3c4d5e6f70',
      nickname: '林晓明',
      initials: '林',
      role: UserRole.debtor,
      kycLevel: 3,
      riskLevel: 1,
      city: '杭州',
      occupation: '前餐饮店主',
      mbti: 'ENFP',
      level: 12,
      exp: 3840,
      lightPoints: 12860,
      valueScore: 4260,
      redeemProgressPct: 42.6,
      carbonDebtSaved: 58200,
      walletBalance: 1286.50,
      walletFrozen: 300,
      capabilityTags: ['短视频剪辑', '餐饮运营', '本地生活', '直播话术', '客服沟通'],
      permissions: ['user.profile.read', 'user.profile.write', 'debt.case.view.self', 'task.accept', 'content.publish', 'finance.wallet.withdraw'],
      inviteCode: 'XG7K2M9P',
      creditScore: 612,
    ),
    'U1002': UserProfile(
      userId: 'U1002',
      uuid: 'b4e8d1f2c6a95b1e8d2b3c4d5e6f7081',
      nickname: '苏雨桐',
      initials: '苏',
      role: UserRole.creator,
      kycLevel: 4,
      riskLevel: 0,
      city: '成都',
      occupation: '自由创作者',
      mbti: 'INFJ',
      level: 21,
      exp: 9120,
      lightPoints: 38420,
      valueScore: 7830,
      redeemProgressPct: 71.3,
      carbonDebtSaved: 142600,
      walletBalance: 8620.00,
      walletFrozen: 0,
      capabilityTags: ['图文种草', '情感疗愈', '理财科普', '直播带货', '文案写作', 'AI绘画'],
      permissions: ['user.profile.read', 'user.profile.write', 'debt.case.view.self', 'task.accept', 'content.publish', 'finance.wallet.withdraw', 'live.create'],
      inviteCode: 'XG3H8N5Q',
      creditScore: 688,
    ),
    'U1003': UserProfile(
      userId: 'U1003',
      uuid: 'c5f7e2a3d8b06c2f7e3c4d5e6f708192',
      nickname: '星辰品牌',
      initials: '星',
      role: UserRole.merchant,
      kycLevel: 5,
      riskLevel: 0,
      city: '深圳',
      occupation: '国货护肤品牌',
      mbti: 'ENTJ',
      level: 8,
      exp: 2100,
      lightPoints: 5000,
      valueScore: 3200,
      redeemProgressPct: 0,
      carbonDebtSaved: 0,
      walletBalance: 128000.00,
      walletFrozen: 24000,
      capabilityTags: ['品牌方', '任务发布', '达人合作'],
      permissions: ['user.profile.read', 'task.publish', 'task.review', 'task.ai.match', 'commerce.product.manage', 'finance.wallet.recharge'],
      inviteCode: 'XG9B2V7L',
      creditScore: 750,
    ),
    'U1004': UserProfile(
      userId: 'U1004',
      uuid: 'd6a8f3b4e9c17d3a8f4d5e6f70819203',
      nickname: '陈锐',
      initials: '陈',
      role: UserRole.riskOfficer,
      kycLevel: 5,
      city: '上海',
      occupation: '风控专员 · RC-208 案件管理',
      mbti: 'ISTJ',
      level: 1,
      capabilityTags: ['反欺诈', 'AML', '规则引擎'],
      permissions: ['risk.case.view', 'risk.case.dispose', 'risk.rule.read', 'risk.rule.create', 'user.status.freeze', 'audit.log.read'],
      inviteCode: 'XG1R5K8D',
    ),
    'U1005': UserProfile(
      userId: 'U1005',
      uuid: 'e7b9a4c5f0d28e4b9a5e6f7081920314',
      nickname: '周梦',
      initials: '周',
      role: UserRole.opsManager,
      kycLevel: 5,
      city: '北京',
      occupation: '运营经理 · OP-106 数据看板',
      mbti: 'ENFJ',
      level: 1,
      capabilityTags: ['内容运营', '增长实验', '数据分析'],
      permissions: ['ops.dashboard.read', 'content.moderation.approve', 'content.moderation.reject', 'task.audit', 'user.search', 'ops.coupon.issue', 'ops.offset_rule.read', 'ops.offset_rule.write', 'ops.offset_rule.publish'],
      inviteCode: 'XG6M4W2Z',
    ),
    'U1006': UserProfile(
      userId: 'U1006',
      uuid: 'f8c0b5d6a1e39f5c0b6f70819203142a',
      nickname: '顾承业',
      initials: '顾',
      role: UserRole.bankOfficer,
      kycLevel: 5,
      city: '深圳',
      occupation: '清收专员 · 协商还款组',
      mbti: 'ESTJ',
      level: 1,
      capabilityTags: ['协商还款', '账务核销', '合规审查'],
      permissions: ['bank.clearance.view', 'bank.clearance.accept', 'bank.clearance.confirm_remit', 'bank.clearance.write_off', 'bank.clearance.batch_write_off', 'bank.clearance.reject', 'bank.certificate.issue', 'bank.recon.generate', 'bank.recon.confirm', 'debt.case.view.tenant'],
      inviteCode: 'XGBK01CM',
      orgName: '招商银行信用卡中心',
    ),
  };

  late final Map<String, DebtProfile> debtProfiles = {
    'U1001': DebtProfile(
      totalDebt: 136500,
      debtCount: 4,
      overdueDaysMax: 96,
      overdueAmount: 41200,
      creditCard: 48500,
      consumerLoan: 32000,
      p2p: 26000,
      bankLoan: 30000,
      multiBorrowIndex: 58.4,
      repaymentWillingness: 86.2,
      repaymentAbility: 52.7,
      monthlyIncome: 6800,
      incomeVerified: true,
      weeklySnapshots: [194700, 190200, 184800, 176300, 168900, 160400, 152100, 146800, 141300, 136500],
    ),
    'U1002': DebtProfile(
      totalDebt: 57400,
      debtCount: 2,
      overdueDaysMax: 12,
      overdueAmount: 3200,
      creditCard: 37400,
      consumerLoan: 20000,
      multiBorrowIndex: 22.1,
      repaymentWillingness: 94.5,
      repaymentAbility: 78.3,
      monthlyIncome: 15200,
      incomeVerified: true,
      weeklySnapshots: [200000, 186000, 168000, 149000, 128000, 112000, 96000, 81000, 68000, 57400],
    ),
  };

  // ───── 债务案件 ─────
  late final List<DebtCase> debtCases = [
    DebtCase(caseId: 'DC2001', userId: 'U1001', creditorName: '招商银行信用卡中心', caseNo: 'CMB-CC-2025-118823', debtType: DebtType.creditCard, principal: 42000, interest: 4200, penalty: 2300, outstanding: 48500, overdueDays: 96, importSource: 'pboc_credit', consentId: 'CS-8f2a1c', negotiationStatus: 3, planId: 'RP3001'),
    DebtCase(caseId: 'DC2002', userId: 'U1001', creditorName: '招联消费金融', caseNo: 'MU-CL-2025-77120', debtType: DebtType.consumerLoan, principal: 30000, interest: 1600, penalty: 400, outstanding: 32000, overdueDays: 45, importSource: 'bank_api', consentId: 'CS-8f2a1c', negotiationStatus: 0),
    DebtCase(caseId: 'DC2003', userId: 'U1001', creditorName: '某网贷平台（已转 AMC）', caseNo: 'AMC-HD-2025-00931', debtType: DebtType.p2p, principal: 22000, interest: 3000, penalty: 1000, outstanding: 26000, overdueDays: 88, importSource: 'amc_batch', consentId: 'CS-8f2a1c', negotiationStatus: 1),
    DebtCase(caseId: 'DC2004', userId: 'U1001', creditorName: '杭州银行 · 经营贷', caseNo: 'HZB-BL-2024-5521', debtType: DebtType.bankLoan, principal: 30000, interest: 0, penalty: 0, outstanding: 30000, overdueDays: 0, importSource: 'user_manual', consentId: 'CS-8f2a1c', negotiationStatus: 0),
    DebtCase(caseId: 'DC2005', userId: 'U1002', creditorName: '交通银行信用卡中心', caseNo: 'BOCOM-CC-2025-33017', debtType: DebtType.creditCard, principal: 35000, interest: 1800, penalty: 600, outstanding: 37400, overdueDays: 12, importSource: 'pboc_credit', consentId: 'CS-1d9e7b', negotiationStatus: 3, planId: 'RP3002'),
    DebtCase(caseId: 'DC2006', userId: 'U1002', creditorName: '马上消费金融', caseNo: 'MSXF-2025-08812', debtType: DebtType.consumerLoan, principal: 20000, interest: 0, penalty: 0, outstanding: 20000, overdueDays: 0, importSource: 'bank_api', consentId: 'CS-1d9e7b', negotiationStatus: 0),
  ];

  late final List<RepaymentPlan> plans = [
    RepaymentPlan(planId: 'RP3001', caseId: 'DC2001', planType: 'mixed', title: '停息挂账 · 24 期 + 流量还债', summary: '与招行协商停息挂账，罚息减免 2,300 元，剩余按 24 期分期；每月任务/内容收益按 60% 自动划入。', totalAmount: 46200, reductionAmount: 2300, periods: 24, monthlyAmount: 1925, model: 'GPT-4o', status: 3, paidPeriods: 7, userConfirmedAt: DateTime(2026, 2, 3), creditorConfirmedAt: DateTime(2026, 2, 6)),
    RepaymentPlan(planId: 'RP3002', caseId: 'DC2005', planType: 'installment', title: '12 期分期 · 利息减免', summary: '交行同意减免 50% 利息，12 期分期，每期 3,041 元。', totalAmount: 36500, reductionAmount: 900, periods: 12, monthlyAmount: 3041.67, model: 'DeepSeek-V3', status: 3, paidPeriods: 9, userConfirmedAt: DateTime(2025, 12, 10), creditorConfirmedAt: DateTime(2025, 12, 12)),
  ];

  late final List<LedgerEntry> ledger = [
    LedgerEntry(entryId: 'LE1', txId: 'TX90001', account: '平台待结算账户', direction: 'D', amount: 1925, businessType: 'repay', businessRefId: 'RP3001-P7', balanceAfter: 128400, opType: 1, createdAt: DateTime(2026, 9, 5, 2, 0)),
    LedgerEntry(entryId: 'LE2', txId: 'TX90001', account: '用户 U1001 债务本金', direction: 'C', amount: 1925, businessType: 'repay', businessRefId: 'RP3001-P7', balanceAfter: 33225, opType: 1, createdAt: DateTime(2026, 9, 5, 2, 0)),
    LedgerEntry(entryId: 'LE3', txId: 'TX90002', account: '商家 U1003 保证金账户', direction: 'D', amount: 380, businessType: 'commission', businessRefId: 'TO5002', balanceAfter: 23620, opType: 1, createdAt: DateTime(2026, 9, 8, 14, 22)),
    LedgerEntry(entryId: 'LE4', txId: 'TX90002', account: '用户 U1001 钱包', direction: 'C', amount: 136.8, businessType: 'task_income', businessRefId: 'TO5002', balanceAfter: 1286.5, opType: 1, createdAt: DateTime(2026, 9, 8, 14, 22)),
    LedgerEntry(entryId: 'LE5', txId: 'TX90002', account: '用户 U1001 债务本金', direction: 'C', amount: 205.2, businessType: 'traffic_repay', businessRefId: 'TO5002', balanceAfter: 33019.8, opType: 1, createdAt: DateTime(2026, 9, 8, 14, 22)),
    LedgerEntry(entryId: 'LE6', txId: 'TX90002', account: '平台服务费收入', direction: 'C', amount: 38, businessType: 'platform_fee', businessRefId: 'TO5002', balanceAfter: 812340, opType: 1, createdAt: DateTime(2026, 9, 8, 14, 22)),
  ];

  late final List<WalletTx> walletTxs = [
    WalletTx(txId: 'TX90002', type: 'task_income', title: '任务结算 · 国货护肤短视频 (提现 40%)', amount: 136.8, createdAt: DateTime(2026, 9, 8, 14, 22)),
    WalletTx(txId: 'TX90002R', type: 'repay', title: '流量还债 · 划入招行方案 (60%)', amount: -205.2, createdAt: DateTime(2026, 9, 8, 14, 22)),
    WalletTx(txId: 'TX90001', type: 'repay', title: '还款方案 RP3001 第 7 期自动扣款', amount: -1925, createdAt: DateTime(2026, 9, 5, 2, 0)),
    WalletTx(txId: 'TX89990', type: 'content_income', title: '内容收益 · 《负债 13 万后我怎么活下来》', amount: 428.6, createdAt: DateTime(2026, 9, 2, 10, 5)),
    WalletTx(txId: 'TX89980', type: 'recharge', title: '微信充值', amount: 2000, createdAt: DateTime(2026, 9, 1, 20, 15)),
    WalletTx(txId: 'TX89970', type: 'withdraw', title: '提现至招商银行 (尾号 6621)', amount: -500, createdAt: DateTime(2026, 8, 28, 16, 40), status: 'frozen'),
  ];

  // ───── 任务 ─────
  late final List<Task> tasks = [
    Task(taskId: 'T4001', publisherId: 'U1003', publisherName: '星辰品牌', taskType: '内容创作', title: '国货护肤新品「星辰晨露精华」短视频种草', description: '拍摄 30~60 秒竖版短视频，突出「敏感肌可用」「早 C 晚 A 平替」卖点，发布至抖音/小红书并挂平台归因短链。需保留原始素材 30 天。', rewardAmount: 380, splitPolicy: const SplitPolicy(cashPct: 40, repayPct: 60), maxParticipants: 50, currentParticipants: 23, kycLevelRequired: 2, valueScoreMin: 2000, targetTags: ['短视频剪辑', '美妆', '本地生活'], deadlineAt: DateTime(2026, 9, 25), depositAmount: 19000, status: 2, createdAt: DateTime(2026, 9, 1)),
    Task(taskId: 'T4002', publisherId: 'U1003', publisherName: '星辰品牌', taskType: '推广', title: '私域社群拉新 · 每有效用户 12 元', description: '将品牌企微二维码分享至你的私域社群，每位完成首单的新用户计 1 个有效转化。归因窗口 7 天，末次点击模型。', rewardAmount: 12, rewardType: 2, splitPolicy: const SplitPolicy(cashPct: 50, repayPct: 50), maxParticipants: 500, currentParticipants: 312, kycLevelRequired: 1, valueScoreMin: 500, targetTags: ['私域运营', '客服沟通'], deadlineAt: DateTime(2026, 10, 15), depositAmount: 6000, status: 2, createdAt: DateTime(2026, 8, 20)),
    Task(taskId: 'T4003', publisherId: 'U9001', publisherName: '新光云官方', taskType: '调研', title: '负债人金融服务体验问卷（20 题）', description: '平台官方调研，用于优化 AI 债务规划师。完成后 24 小时内自动结算，100% 光芒值 + 30 元。', rewardAmount: 30, splitPolicy: const SplitPolicy(cashPct: 0, repayPct: 100, platformFeePct: 0), maxParticipants: 2000, currentParticipants: 1466, kycLevelRequired: 1, valueScoreMin: 0, targetTags: [], deadlineAt: DateTime(2026, 9, 30), depositAmount: 60000, status: 2, createdAt: DateTime(2026, 9, 3)),
    Task(taskId: 'T4004', publisherId: 'U9002', publisherName: '云栖餐饮集团', taskType: '技能服务', title: '餐饮门店线上运营顾问（远程 · 2 周）', description: '为 3 家新开门店搭建美团/抖音团购运营方案，需有餐饮运营经验。按周结算。', rewardAmount: 2800, splitPolicy: const SplitPolicy(cashPct: 30, repayPct: 70), maxParticipants: 3, currentParticipants: 1, kycLevelRequired: 3, valueScoreMin: 3500, targetTags: ['餐饮运营', '本地生活'], deadlineAt: DateTime(2026, 9, 28), depositAmount: 8400, status: 2, createdAt: DateTime(2026, 9, 6)),
    Task(taskId: 'T4005', publisherId: 'U9003', publisherName: '橙光教育', taskType: '客服', title: 'AI 陪练课程夜间在线客服（19:00-23:00）', description: '在企微客服工作台接待家长咨询，AI 商业分身可辅助回复。按有效接待量阶梯计酬。', rewardAmount: 150, rewardType: 2, splitPolicy: const SplitPolicy(cashPct: 60, repayPct: 40), maxParticipants: 20, currentParticipants: 20, kycLevelRequired: 2, valueScoreMin: 1500, targetTags: ['客服沟通'], deadlineAt: DateTime(2026, 9, 20), depositAmount: 3000, status: 3, createdAt: DateTime(2026, 8, 25)),
    Task(taskId: 'T4006', publisherId: 'U9004', publisherName: '知了心理', taskType: '内容创作', title: '「走出债务焦虑」情感疗愈图文系列（3 篇）', description: '结合真实经历撰写 3 篇 800 字以上图文，AI 创作助手可辅助但需标注 AI 生成比例。', rewardAmount: 600, splitPolicy: const SplitPolicy(cashPct: 50, repayPct: 50), maxParticipants: 10, currentParticipants: 4, kycLevelRequired: 2, valueScoreMin: 2500, targetTags: ['情感疗愈', '文案写作'], deadlineAt: DateTime(2026, 10, 5), depositAmount: 6000, status: 2, createdAt: DateTime(2026, 9, 8)),
  ];

  late final List<TaskOrder> orders = [
    TaskOrder(orderId: 'TO5001', taskId: 'T4005', userId: 'U1001', status: OrderStatus.executing, createdAt: DateTime(2026, 8, 26, 10), history: [
      OrderTransition(from: 0, to: 10, operator: 'U1001', reasonCode: 'ACCEPT', evidence: 'API-T-004', at: DateTime(2026, 8, 26, 10)),
      OrderTransition(from: 10, to: 20, operator: 'SYSTEM', reasonCode: 'AUTO_CONFIRM', evidence: '商家自动确认', at: DateTime(2026, 8, 26, 10, 1)),
    ]),
    TaskOrder(orderId: 'TO5002', taskId: 'T4001', userId: 'U1001', status: OrderStatus.settled, aiCheckAttempts: 1, aiCheckScore: 93.5, submission: 'https://v.douyin.com/xg-demo-0908 · 已挂归因短链', settlementId: 'ST6001', createdAt: DateTime(2026, 9, 2, 9), history: [
      OrderTransition(from: 0, to: 10, operator: 'U1001', reasonCode: 'ACCEPT', evidence: 'API-T-004', at: DateTime(2026, 9, 2, 9)),
      OrderTransition(from: 10, to: 20, operator: 'U1003', reasonCode: 'MERCHANT_CONFIRM', evidence: '手动确认', at: DateTime(2026, 9, 2, 11)),
      OrderTransition(from: 20, to: 40, operator: 'U1001', reasonCode: 'SUBMIT', evidence: 'API-T-005', at: DateTime(2026, 9, 7, 18)),
      OrderTransition(from: 40, to: 50, operator: 'AI', reasonCode: 'AI_CHECK_PASS', evidence: '原创性 93.5 / 无搬运', at: DateTime(2026, 9, 7, 18, 0, 4)),
      OrderTransition(from: 50, to: 60, operator: 'U1003', reasonCode: 'MERCHANT_APPROVE', evidence: 'API-T-006', at: DateTime(2026, 9, 8, 14, 20)),
      OrderTransition(from: 60, to: 80, operator: 'SYSTEM', reasonCode: 'SETTLED', evidence: 'TX90002 复式记账 4 分录', at: DateTime(2026, 9, 8, 14, 22)),
    ]),
    TaskOrder(orderId: 'TO5003', taskId: 'T4001', userId: 'U1002', status: OrderStatus.awaitingReview, aiCheckAttempts: 1, aiCheckScore: 96.2, submission: 'https://xhs.demo/p/xg-0910 · 图文 + 视频双发', createdAt: DateTime(2026, 9, 4), history: [
      OrderTransition(from: 0, to: 10, operator: 'U1002', reasonCode: 'ACCEPT', evidence: 'API-T-004', at: DateTime(2026, 9, 4)),
      OrderTransition(from: 10, to: 20, operator: 'SYSTEM', reasonCode: 'AUTO_CONFIRM', evidence: '', at: DateTime(2026, 9, 4, 0, 1)),
      OrderTransition(from: 20, to: 40, operator: 'U1002', reasonCode: 'SUBMIT', evidence: 'API-T-005', at: DateTime(2026, 9, 10, 20)),
      OrderTransition(from: 40, to: 50, operator: 'AI', reasonCode: 'AI_CHECK_PASS', evidence: '原创性 96.2', at: DateTime(2026, 9, 10, 20, 0, 3)),
    ]),
    TaskOrder(orderId: 'TO5004', taskId: 'T4002', userId: 'U1002', status: OrderStatus.executing, createdAt: DateTime(2026, 9, 1), history: [
      OrderTransition(from: 0, to: 10, operator: 'U1002', reasonCode: 'ACCEPT', evidence: '', at: DateTime(2026, 9, 1)),
      OrderTransition(from: 10, to: 20, operator: 'SYSTEM', reasonCode: 'AUTO_CONFIRM', evidence: '', at: DateTime(2026, 9, 1)),
    ]),
  ];

  late final List<Settlement> settlements = [
    Settlement(settlementId: 'ST6001', orderId: 'TO5002', userId: 'U1001', gross: 380, cashPart: 136.8, repayPart: 205.2, platformFee: 38, createdAt: DateTime(2026, 9, 8, 14, 22)),
  ];

  // ───── 内容 ─────
  late final List<Content> contents = [
    Content(contentId: 'C7001', authorId: 'U1002', authorName: '苏雨桐', contentType: 1, title: '负债 20 万到只剩 5 万，我用了 10 个月做对了三件事', body: '第一件事是停止逃避，把所有债务导入平台做了一次完整的负债画像……第二件事是让 AI 债务规划师帮我算清楚每一分钱的去向……第三件事是把创作变成还债的引擎。', tags: ['真实经历', '流量还债', '理财科普'], moderationStatus: 2, aiScore: 88, viewCount: 128400, likeCount: 9632, commentCount: 1210, shareCount: 2380, revenueAmount: 4826, revenueRepayAmount: 2896, publishedAt: DateTime(2026, 9, 3)),
    Content(contentId: 'C7002', authorId: 'U1001', authorName: '林晓明', contentType: 2, title: '餐饮店倒闭后，我在新光云接的第一个单', body: '视频记录了第一次接到品牌短视频任务的全过程，收益 380 元，其中 60% 自动还给了招行。', tags: ['真实经历', '任务接单'], moderationStatus: 1, aiScore: 94, viewCount: 32100, likeCount: 2140, commentCount: 388, shareCount: 512, revenueAmount: 428.6, revenueRepayAmount: 257.2, publishedAt: DateTime(2026, 9, 1)),
    Content(contentId: 'C7003', authorId: 'U1002', authorName: '苏雨桐', contentType: 1, title: '停息挂账怎么谈？我和 AI 谈判专家一起写的协商函（附模板）', body: '协商函核心三段：现状陈述、还款能力证明、诚意方案。AI 帮我把语气从"哀求"调整为"专业"，银行 3 天就回复了。', tags: ['谈判技巧', 'AI工具'], aiGenerated: true, moderationStatus: 2, aiScore: 91, viewCount: 86200, likeCount: 6410, commentCount: 920, shareCount: 3100, revenueAmount: 3120, revenueRepayAmount: 1872, publishedAt: DateTime(2026, 8, 28)),
    Content(contentId: 'C7004', authorId: 'U1001', authorName: '林晓明', contentType: 1, title: '【草稿】关于催收电话，你必须知道的 5 条合法边界', body: '催收时段只能是 08:00~20:00；不得联系无关第三人；不得威胁侮辱……（内容含"催收"关键词，触发人工复审）', tags: ['法律科普', '催收合规'], moderationStatus: 0, aiScore: 76, status: 0, publishedAt: DateTime(2026, 9, 10)),
    Content(contentId: 'C7005', authorId: 'U8801', authorName: '债务同盟·老K', contentType: 2, title: '3 天上岸！内部渠道帮你消除征信逾期，加我 V：xxx', body: '（诱导跳转 + 虚假宣传，AI 初审拦截）', tags: [], moderationStatus: 0, aiScore: 12, status: 0, publishedAt: DateTime(2026, 9, 11, 8)),
    Content(contentId: 'C7006', authorId: 'U8802', authorName: '心灵驿站·阿May', contentType: 5, title: '深夜电台：给正在失眠的负债人', body: '一段 18 分钟的音频陪伴，来自曾经的负债人。', tags: ['心灵驿站', '互助'], moderationStatus: 0, aiScore: 89, status: 0, publishedAt: DateTime(2026, 9, 11, 7)),
  ];

  // ───── 风控 ─────
  late final List<RiskCase> riskCases = [
    RiskCase(caseId: 'RC8001', userId: 'U8801', userName: '债务同盟·老K', ruleCode: 'CNT-INDUCE-003', ruleName: '内容含引流联系方式 + 征信修复话术', scene: 'content', score: 96, level: 3, suggestedAction: 'block + review', createdAt: DateTime(2026, 9, 11, 8, 2)),
    RiskCase(caseId: 'RC8002', userId: 'U1001', userName: '林晓明', ruleCode: 'WD-GEO-011', ruleName: '提现异地 + 新设备', scene: 'withdraw', score: 78, level: 2, suggestedAction: 'challenge (短信+活体)', status: 'reviewing', createdAt: DateTime(2026, 8, 28, 16, 41)),
    RiskCase(caseId: 'RC8003', userId: 'U8803', userName: '匿名用户 8803', ruleCode: 'REG-IP-001', ruleName: '同 IP 1 小时注册 > 20 次', scene: 'register', score: 100, level: 4, suggestedAction: 'block + freeze + report', createdAt: DateTime(2026, 9, 11, 3, 15)),
    RiskCase(caseId: 'RC8004', userId: 'U8804', userName: '创作者 8804', ruleCode: 'TSK-DUP-005', ruleName: '交付物搬运检测相似度 92%', scene: 'task', score: 85, level: 2, suggestedAction: 'review', createdAt: DateTime(2026, 9, 10, 22, 5)),
    RiskCase(caseId: 'RC8005', userId: 'U8805', userName: '商家 8805', ruleCode: 'AML-LARGE-002', ruleName: '单日充值 > 20 万 且 快速提现', scene: 'pay', score: 92, level: 3, suggestedAction: 'freeze + EDD 尽调', createdAt: DateTime(2026, 9, 10, 15, 30)),
  ];

  late final List<RiskRule> riskRules = [
    RiskRule(ruleCode: 'REG-IP-001', ruleName: '同 IP 高频注册', scene: 'register', expression: 'ip.recent_1h.count > 20 && device.new', riskScore: 100, action: 'block', hitCount24h: 37, fpRate: 0.004),
    RiskRule(ruleCode: 'LOGIN-GEO-002', ruleName: '异地登录 + 夜间', scene: 'login', expression: 'geo.distance_km > 500 && hour in [1..5]', riskScore: 75, action: 'challenge', hitCount24h: 212, fpRate: 0.062),
    RiskRule(ruleCode: 'CNT-INDUCE-003', ruleName: '引流联系方式 + 征信修复', scene: 'content', expression: 'text.has_contact && text.match("征信修复|内部渠道|消除逾期")', riskScore: 96, action: 'block', hitCount24h: 58, fpRate: 0.011),
    RiskRule(ruleCode: 'TSK-DUP-005', ruleName: '交付物搬运检测', scene: 'task', expression: 'media.dna_similarity > 0.85', riskScore: 85, action: 'review', hitCount24h: 14, fpRate: 0.083),
    RiskRule(ruleCode: 'WD-GEO-011', ruleName: '提现异地新设备', scene: 'withdraw', expression: 'device.new && geo.city != user.city', riskScore: 78, action: 'challenge', hitCount24h: 41, fpRate: 0.15),
    RiskRule(ruleCode: 'AML-LARGE-002', ruleName: '大额快进快出', scene: 'pay', expression: 'recharge.day_sum > 200000 && withdraw.within_hours(6)', riskScore: 92, action: 'review', hitCount24h: 3, fpRate: 0.0),
    RiskRule(ruleCode: 'AI-INJECT-007', ruleName: 'Prompt 注入检测', scene: 'ai', expression: 'prompt.injection_score > 0.8', riskScore: 70, action: 'warn', status: 1, hitCount24h: 126, fpRate: 0.21),
  ];

  // ───── 债务积分 / 商城 / 清缴 ─────
  static const products = <Product>[
    Product(skuId: 'SKU-MOVIE', name: '电影票 · 《黎明之前》2D 单人', category: '本地生活', merchant: '星光影城', price: 45, platformMargin: 5, offsetMultiplier: 5, emoji: '🎬', desc: '平台利润 ¥5 × 5 倍 = 抵债 25 DP'),
    Product(skuId: 'SKU-COFFEE', name: '生椰拿铁 · 大杯', category: '餐饮', merchant: '瓑幸咖啡', price: 19.9, platformMargin: 2, offsetMultiplier: 5, emoji: '☕', desc: '平台利润 ¥2 × 5 倍 = 抵债 10 DP'),
    Product(skuId: 'SKU-SERUM', name: '星辰晨露精华 30ml', category: '美妆', merchant: '星辰品牌', price: 129, platformMargin: 18, offsetMultiplier: 4, emoji: '✨', desc: '平台利润 ¥18 × 4 倍 = 抵债 72 DP'),
    Product(skuId: 'SKU-PHONE', name: '话费充值 100 元', category: '生活缴费', merchant: '中国移动', price: 100, platformMargin: 1.5, offsetMultiplier: 5, emoji: '📱', desc: '平台利润 ¥1.5 × 5 倍 = 抵债 7.5 DP'),
    Product(skuId: 'SKU-COURSE', name: '《短视频剪辑从 0 到 1》课程', category: '教育', merchant: '橙光教育', price: 199, platformMargin: 60, offsetMultiplier: 3, emoji: '🎓', desc: '平台利润 ¥60 × 3 倍 = 抵债 180 DP · 同时提升能力标签'),
    Product(skuId: 'SKU-GROCERY', name: '生鲜周卡 · 蜡菜包', category: '生鲜', merchant: '叨叨买菜', price: 88, platformMargin: 6, offsetMultiplier: 5, emoji: '🥬', desc: '平台利润 ¥6 × 5 倍 = 抵债 30 DP'),
  ];

  late final List<DebtPointBatch> debtPoints = [
    // DP7001 + DP7002 = 462.4 → 已提交清缴单 CL8002（待银行受理）
    DebtPointBatch(batchId: 'DP7001', userId: 'U1001', source: DebtPointSource.task, faceValue: 205.2, cashBacked: 205.2, refId: 'ST6001', title: '任务结算 · 星辰晨露精华短视频（60%）', consumed: 205.2, createdAt: DateTime(2026, 9, 8, 14, 22)),
    DebtPointBatch(batchId: 'DP7002', userId: 'U1001', source: DebtPointSource.content, faceValue: 257.2, cashBacked: 257.2, refId: 'C7002', title: '内容收益 · 《餐饮店倒闭后…》（60%）', consumed: 257.2, createdAt: DateTime(2026, 9, 2, 10, 5)),
    // DP7008 = 55 → 清缴单 CL8003（已受理）
    DebtPointBatch(batchId: 'DP7008', userId: 'U1001', source: DebtPointSource.consumption, faceValue: 55, cashBacked: 11, refId: 'SO9000', title: '消费平债 · 话费+咖啡合并（利润 ¥11 × 5）', consumed: 55, createdAt: DateTime(2026, 9, 5, 12, 0)),
    // 可用积分
    DebtPointBatch(batchId: 'DP7009', userId: 'U1001', source: DebtPointSource.content, faceValue: 180, cashBacked: 180, refId: 'C7002-TIP', title: '内容收益 · 《餐饮店倒闭后…》打赏（60%）', createdAt: DateTime(2026, 9, 10, 9, 30)),
    DebtPointBatch(batchId: 'DP7010', userId: 'U1001', source: DebtPointSource.task, faceValue: 90, cashBacked: 90, refId: 'ST6000', title: '任务结算 · 平台调研问卷（100%）', createdAt: DateTime(2026, 9, 4, 8, 0)),
    DebtPointBatch(batchId: 'DP7003', userId: 'U1001', source: DebtPointSource.consumption, faceValue: 25, cashBacked: 5, refId: 'SO9001', title: '消费平债 · 电影票（利润 ¥5 × 5）', createdAt: DateTime(2026, 9, 6, 19, 40)),
    DebtPointBatch(batchId: 'DP7004', userId: 'U1001', source: DebtPointSource.consumption, faceValue: 30, cashBacked: 6, refId: 'SO9002', title: '消费平债 · 生鲜周卡（利润 ¥6 × 5）', createdAt: DateTime(2026, 9, 9, 8, 12)),
    DebtPointBatch(batchId: 'DP7005', userId: 'U1002', source: DebtPointSource.content, faceValue: 2896, cashBacked: 2896, refId: 'C7001', title: '内容收益 · 《负债 20 万到只剩 5 万》（60%）', consumed: 2896, createdAt: DateTime(2026, 9, 3)),
    DebtPointBatch(batchId: 'DP7006', userId: 'U1002', source: DebtPointSource.content, faceValue: 1872, cashBacked: 1872, refId: 'C7003', title: '内容收益 · 《停息挂账怎么谈》（60%）', createdAt: DateTime(2026, 8, 28)),
    DebtPointBatch(batchId: 'DP7007', userId: 'U1002', source: DebtPointSource.consumption, faceValue: 180, cashBacked: 60, refId: 'SO9003', title: '消费平债 · 剪辑课程（利润 ¥60 × 3）', createdAt: DateTime(2026, 9, 7)),
  ];

  late final List<ShopOrder> shopOrders = [
    ShopOrder(orderId: 'SO9001', userId: 'U1001', skuId: 'SKU-MOVIE', name: '电影票 · 《黎明之前》', price: 45, platformMargin: 5, offsetAmount: 25, dpBatchId: 'DP7003', createdAt: DateTime(2026, 9, 6, 19, 40), status: 'fulfilled'),
    ShopOrder(orderId: 'SO9002', userId: 'U1001', skuId: 'SKU-GROCERY', name: '生鲜周卡 · 蜡菜包', price: 88, platformMargin: 6, offsetAmount: 30, dpBatchId: 'DP7004', createdAt: DateTime(2026, 9, 9, 8, 12)),
    ShopOrder(orderId: 'SO9003', userId: 'U1002', skuId: 'SKU-COURSE', name: '《短视频剪辑从 0 到 1》', price: 199, platformMargin: 60, offsetAmount: 180, dpBatchId: 'DP7007', createdAt: DateTime(2026, 9, 7), status: 'fulfilled'),
  ];

  late final List<ClearanceOrder> clearances = [
    ClearanceOrder(clearanceId: 'CL8001', userId: 'U1002', caseId: 'DC2005', bankName: '交通银行信用卡中心', points: 2896, cashRemitted: 2896, reductionAccepted: 0, status: ClearanceStatus.done, bankOperator: '交行·李专员', createdAt: DateTime(2026, 9, 4), history: [
      ClearanceEvent(10, '用户提交 2,896 DP · 现金背书 100%', DateTime(2026, 9, 4, 10), operator: 'USER:U1002'),
      ClearanceEvent(20, '银行受理 · 核验 Consent & 积分背书比例', DateTime(2026, 9, 4, 10, 30), operator: 'BANK:李专员'),
      ClearanceEvent(30, '确认收到平台存管汇款 ¥2,896.00 · TX90010', DateTime(2026, 9, 4, 15), operator: 'BANK:李专员'),
      ClearanceEvent(40, '核销债务 ¥2,896.00', DateTime(2026, 9, 5, 9), operator: 'BANK:李专员'),
      ClearanceEvent(50, 'Webhook CLEARANCE.COMPLETED', DateTime(2026, 9, 5, 9, 1)),
    ]),
    // 招行待受理队列（银行侧演示）
    ClearanceOrder(clearanceId: 'CL8002', userId: 'U1001', caseId: 'DC2001', bankName: '招商银行信用卡中心', points: 462.4, cashRemitted: 462.4, reductionAccepted: 0, status: ClearanceStatus.submitted, consumedBatches: {'DP7001': 205.2, 'DP7002': 257.2}, createdAt: DateTime(2026, 9, 10, 21, 15), history: [
      ClearanceEvent(10, '用户提交 462.4 DP · 现金背书 100%（任务+内容）', DateTime(2026, 9, 10, 21, 15), operator: 'USER:U1001'),
    ]),
    ClearanceOrder(clearanceId: 'CL8003', userId: 'U1001', caseId: 'DC2001', bankName: '招商银行信用卡中心', points: 55, cashRemitted: 11, reductionAccepted: 44, status: ClearanceStatus.accepted, bankOperator: '顾承业', consumedBatches: {'DP7008': 55}, createdAt: DateTime(2026, 9, 9, 9, 2), history: [
      ClearanceEvent(10, '用户提交 55 DP · 现金背书 20%（消费平债）', DateTime(2026, 9, 9, 9, 2), operator: 'USER:U1001'),
      ClearanceEvent(20, '受理 · 资料齐全，等待平台汇款到账', DateTime(2026, 9, 9, 10, 40), operator: 'BANK:顾承业'),
    ]),
  ];

  late final List<ClearanceCertificate> certificates = [];

  // ───── 平债倍率规则（运营可配） ─────
  late final List<OffsetRule> offsetRules = [
    OffsetRule(ruleId: 'OR-CAT-001', ruleType: 'category', name: '本地生活 · 基础倍率', category: '本地生活', value: 5, createdBy: 'U1005', approvedBy: 'COO', hitCount: 1240),
    OffsetRule(ruleId: 'OR-CAT-002', ruleType: 'category', name: '餐饮 · 基础倍率', category: '餐饮', value: 5, createdBy: 'U1005', approvedBy: 'COO', hitCount: 3860),
    OffsetRule(ruleId: 'OR-CAT-003', ruleType: 'category', name: '美妆 · 基础倍率', category: '美妆', value: 4, createdBy: 'U1005', approvedBy: 'COO', hitCount: 920),
    OffsetRule(ruleId: 'OR-CAT-004', ruleType: 'category', name: '生活缴费 · 基础倍率', category: '生活缴费', value: 5, createdBy: 'U1005', approvedBy: 'COO', hitCount: 5120),
    OffsetRule(ruleId: 'OR-CAT-005', ruleType: 'category', name: '教育 · 基础倍率（能力投资）', category: '教育', value: 3, createdBy: 'U1005', approvedBy: 'COO', hitCount: 410),
    OffsetRule(ruleId: 'OR-CAT-006', ruleType: 'category', name: '生鲜 · 基础倍率（刚需扶持）', category: '生鲜', value: 5, createdBy: 'U1005', approvedBy: 'COO', hitCount: 2210),
    OffsetRule(ruleId: 'OR-CR-001', ruleType: 'credit_tier', name: '信用重塑 550~599 · 无加成', creditMin: 550, creditMax: 599, value: 0, createdBy: 'U1005', approvedBy: 'COO', hitCount: 800),
    OffsetRule(ruleId: 'OR-CR-002', ruleType: 'credit_tier', name: '信用重塑 600~649 · +0.5', creditMin: 600, creditMax: 649, value: 0.5, createdBy: 'U1005', approvedBy: 'COO', hitCount: 2300),
    OffsetRule(ruleId: 'OR-CR-003', ruleType: 'credit_tier', name: '信用重塑 650~699 · +1.0', creditMin: 650, creditMax: 699, value: 1.0, createdBy: 'U1005', approvedBy: 'COO', hitCount: 1650),
    OffsetRule(ruleId: 'OR-CR-004', ruleType: 'credit_tier', name: '信用重塑 700+ · +1.5', creditMin: 700, creditMax: 999, value: 1.5, createdBy: 'U1005', approvedBy: 'COO', hitCount: 420),
    OffsetRule(ruleId: 'OR-CAP-001', ruleType: 'global_cap', name: '全局倍率上限（财务风控红线）', value: 6, createdBy: 'U1005', approvedBy: 'CFO', hitCount: 130),
    OffsetRule(ruleId: 'OR-CAT-007', ruleType: 'category', name: '文娱演出 · 基础倍率（灰度中）', category: '文娱演出', value: 6, status: 1, createdBy: 'U1005', hitCount: 12),
  ];

  // ───── 日终对账文件 ─────
  late final List<ReconFile> reconFiles = [
    ReconFile(
      fileId: 'RF1001',
      fileName: 'XG_CMB_RECON_20260910.csv',
      bankName: '招商银行信用卡中心',
      bizDate: DateTime(2026, 9, 10),
      status: 'confirmed',
      confirmedBy: '顾承业',
      generatedAt: DateTime(2026, 9, 11, 0, 5),
      checksum: 'sha256:7f3a…c21e',
      lines: const [
        ReconLine(clearanceId: 'CL7990', userId: 'U1001', caseNo: 'CMB-CC-2025-118823', platformRemitted: 1925, bankReceived: 1925, writtenOff: 1925, status: 'matched', bankRef: 'UNP20260910001'),
        ReconLine(clearanceId: 'CL7991', userId: 'U8810', caseNo: 'CMB-CC-2025-120044', platformRemitted: 320, bankReceived: 320, writtenOff: 1600, status: 'matched', bankRef: 'UNP20260910002'),
        ReconLine(clearanceId: 'CL7992', userId: 'U8811', caseNo: 'CMB-CC-2025-119870', platformRemitted: 88, bankReceived: 88, writtenOff: 88, status: 'matched', bankRef: 'UNP20260910003'),
      ],
    ),
  ];

  late final List<AppNotification> notifications = [
    AppNotification(id: 'N1', category: 'finance', title: 'REPAYMENT.SUCCESS · 第 7 期还款成功', body: '招商银行方案 RP3001 第 7 期 ¥1,925 已到账，剩余 17 期。赎回进度 +1.4%。', at: DateTime(2026, 9, 5, 2, 1)),
    AppNotification(id: 'N2', category: 'task', title: 'TASK.ORDER.COMPLETED · 任务已结算', body: '「星辰晨露精华」短视频任务结算 ¥380：¥205.2 划入还债，¥136.8 到账钱包。', at: DateTime(2026, 9, 8, 14, 22)),
    AppNotification(id: 'N3', category: 'interact', title: '苏雨桐 赞了你的视频', body: '《餐饮店倒闭后，我在新光云接的第一个单》', at: DateTime(2026, 9, 9, 21, 12), read: true),
    AppNotification(id: 'N4', category: 'system', title: '赋能教练 · 今日打卡提醒', body: '你已连续打卡 23 天，今天的小目标：完成任务 TO5001 的 2 小时客服排班。', at: DateTime(2026, 9, 11, 8, 0)),
  ];

  final List<ApiLog> apiLogs = [];
}
