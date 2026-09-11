/// 新光云 · 领域模型（对应技术蓝图第三部分 字段级设计的精简版）
library;

// ───────────────────────── 用户域 D01 / 认证域 D02 ─────────────────────────

enum UserRole {
  debtor('负债人', 'C端 · 流量还债主角'),
  creator('创作者', 'C端 · 内容变现 + 流量还债'),
  merchant('商家', 'B端 · 任务发布方 / 品牌方'),
  riskOfficer('风控专员', 'M02 · 风控管理域'),
  opsManager('运营经理', 'M01 · 运营管理域');

  final String label;
  final String desc;
  const UserRole(this.label, this.desc);
  bool get isAdmin => this == riskOfficer || this == opsManager;
}

/// 用户状态机：1正常 2冻结 3封禁 4注销中 5已注销
enum UserStatus {
  normal(1, '正常'),
  frozen(2, '冻结'),
  banned(3, '封禁'),
  deactivating(4, '注销中'),
  deactivated(5, '已注销');

  final int code;
  final String label;
  const UserStatus(this.code, this.label);
}

class KycLevel {
  static const names = ['游客', '手机认证', '实名认证', '活体认证', '银行卡认证', '企业认证'];
  static const limits = [0, 0, 500, 5000, 50000, 500000];
  static const unlocks = [
    '浏览公开内容',
    '关注/点赞/评论/接收非金融任务',
    '发布内容/发布小额任务/入驻创作者',
    '参与还债计划/申请 AMC 匹配',
    '提现/接收流量分成/还款代扣',
    'MCN 机构/商城商家/服务商',
  ];
  static String name(int l) => 'L$l ${names[l.clamp(0, 5)]}';
}

class UserProfile {
  final String userId;
  final String uuid;
  String nickname;
  final String initials;
  final UserRole role;
  int kycLevel;
  int riskLevel; // 0低 1中 2高 3极高
  UserStatus status;
  final String city;
  final String occupation;
  final String mbti;
  int level;
  int exp;
  int lightPoints;
  double valueScore;
  double redeemProgressPct;
  double carbonDebtSaved;
  double walletBalance;
  double walletFrozen;
  final List<String> capabilityTags;
  final List<String> permissions;
  final String inviteCode;
  bool hasPayPassword;
  int creditScore;

  UserProfile({
    required this.userId,
    required this.uuid,
    required this.nickname,
    required this.initials,
    required this.role,
    required this.kycLevel,
    this.riskLevel = 0,
    this.status = UserStatus.normal,
    required this.city,
    required this.occupation,
    required this.mbti,
    this.level = 1,
    this.exp = 0,
    this.lightPoints = 0,
    this.valueScore = 0,
    this.redeemProgressPct = 0,
    this.carbonDebtSaved = 0,
    this.walletBalance = 0,
    this.walletFrozen = 0,
    this.capabilityTags = const [],
    this.permissions = const [],
    required this.inviteCode,
    this.hasPayPassword = true,
    this.creditScore = 600,
  });

  bool can(String perm) =>
      permissions.contains('*') || permissions.contains(perm);
}

class DebtProfile {
  double totalDebt;
  int debtCount;
  int overdueDaysMax;
  double overdueAmount;
  double creditCard;
  double consumerLoan;
  double p2p;
  double bankLoan;
  double privateDebt;
  double multiBorrowIndex;
  double repaymentWillingness;
  double repaymentAbility;
  double monthlyIncome;
  bool incomeVerified;
  List<double> weeklySnapshots;

  DebtProfile({
    this.totalDebt = 0,
    this.debtCount = 0,
    this.overdueDaysMax = 0,
    this.overdueAmount = 0,
    this.creditCard = 0,
    this.consumerLoan = 0,
    this.p2p = 0,
    this.bankLoan = 0,
    this.privateDebt = 0,
    this.multiBorrowIndex = 0,
    this.repaymentWillingness = 0,
    this.repaymentAbility = 0,
    this.monthlyIncome = 0,
    this.incomeVerified = false,
    this.weeklySnapshots = const [],
  });
}

// ───────────────────────── 还债与账户域 D06 ─────────────────────────

enum DebtType {
  creditCard('信用卡'),
  consumerLoan('消费金融'),
  p2p('网贷'),
  bankLoan('银行贷款'),
  privateDebt('民间借贷');

  final String label;
  const DebtType(this.label);
}

class DebtCase {
  final String caseId;
  final String userId;
  final String creditorName;
  final String caseNo;
  final DebtType debtType;
  final double principal;
  final double interest;
  final double penalty;
  double outstanding;
  final int overdueDays;
  final String importSource;
  final String consentId;
  int negotiationStatus; // 0未协商 1协商中 2达成方案 3执行中 4已完成 5失败
  int status; // 1活跃 2冻结 3已了结 4法律程序中
  String? planId;

  DebtCase({
    required this.caseId,
    required this.userId,
    required this.creditorName,
    required this.caseNo,
    required this.debtType,
    required this.principal,
    required this.interest,
    required this.penalty,
    required this.outstanding,
    required this.overdueDays,
    required this.importSource,
    required this.consentId,
    this.negotiationStatus = 0,
    this.status = 1,
    this.planId,
  });

  String get bucket {
    if (overdueDays <= 0) return 'M0';
    if (overdueDays <= 30) return 'M1';
    if (overdueDays <= 60) return 'M2';
    if (overdueDays <= 90) return 'M3';
    if (overdueDays <= 180) return 'M6';
    return 'M6+';
  }

  static const negotiationLabels = ['未协商', '协商中', '达成方案', '执行中', '已完成', '谈判失败'];
  String get negotiationLabel => negotiationLabels[negotiationStatus];
  static const statusLabels = ['', '活跃', '冻结', '已了结', '法律程序中'];
  String get statusLabel => statusLabels[status];
}

/// 还款方案状态：0草稿 1待用户确认 2待债权方确认 3执行中 4已完成 5违约 6已终止
class RepaymentPlan {
  final String planId;
  final String caseId;
  final String planType; // installment / lump_sum / traffic_repay / mixed
  final String title;
  final String summary;
  final double totalAmount;
  final double reductionAmount;
  final int periods;
  final double monthlyAmount;
  final bool aiGenerated;
  final String model;
  int status;
  int paidPeriods;
  DateTime? userConfirmedAt;
  DateTime? creditorConfirmedAt;

  RepaymentPlan({
    required this.planId,
    required this.caseId,
    required this.planType,
    required this.title,
    required this.summary,
    required this.totalAmount,
    required this.reductionAmount,
    required this.periods,
    required this.monthlyAmount,
    this.aiGenerated = true,
    this.model = 'GPT-4o',
    this.status = 0,
    this.paidPeriods = 0,
    this.userConfirmedAt,
    this.creditorConfirmedAt,
  });

  static const statusLabels = ['草稿', '待用户确认', '待债权方确认', '执行中', '已完成', '违约', '已终止'];
  String get statusLabel => statusLabels[status];
  double get paidAmount => paidPeriods * monthlyAmount;
  double get progress => periods == 0 ? 0 : paidPeriods / periods;
}

class LedgerEntry {
  final String entryId;
  final String txId;
  final String account;
  final String direction; // D / C
  final double amount;
  final String businessType;
  final String businessRefId;
  final double balanceAfter;
  final int opType; // 1系统 2用户 3AI 4后台
  final DateTime createdAt;

  LedgerEntry({
    required this.entryId,
    required this.txId,
    required this.account,
    required this.direction,
    required this.amount,
    required this.businessType,
    required this.businessRefId,
    required this.balanceAfter,
    required this.opType,
    required this.createdAt,
  });
}

class WalletTx {
  final String txId;
  final String type; // recharge / repay / withdraw / task_income / content_income / refund
  final String title;
  final double amount; // 正入 负出
  final DateTime createdAt;
  final String status; // success / pending / frozen

  WalletTx({
    required this.txId,
    required this.type,
    required this.title,
    required this.amount,
    required this.createdAt,
    this.status = 'success',
  });
}

// ───────────────────────── 任务与流量域 D05 ─────────────────────────

class SplitPolicy {
  final int cashPct;
  final int repayPct;
  final int platformFeePct;
  const SplitPolicy({
    required this.cashPct,
    required this.repayPct,
    this.platformFeePct = 10,
  });
  String get label => '还债$repayPct% / 提现$cashPct% / 平台$platformFeePct%';
}

/// 任务状态 0草稿 1审核中 2招募中 3执行中 4结算中 5已完成 6已取消 7争议中
class Task {
  final String taskId;
  final String publisherId;
  final String publisherName;
  final String taskType;
  final String title;
  final String description;
  final double rewardAmount;
  final int rewardType; // 1固定 2阶梯 3竞价
  SplitPolicy splitPolicy;
  final int maxParticipants;
  int currentParticipants;
  final int kycLevelRequired;
  final int valueScoreMin;
  final List<String> targetTags;
  final DateTime deadlineAt;
  final double depositAmount;
  int status;
  final DateTime createdAt;

  Task({
    required this.taskId,
    required this.publisherId,
    required this.publisherName,
    required this.taskType,
    required this.title,
    required this.description,
    required this.rewardAmount,
    this.rewardType = 1,
    required this.splitPolicy,
    required this.maxParticipants,
    this.currentParticipants = 0,
    required this.kycLevelRequired,
    required this.valueScoreMin,
    required this.targetTags,
    required this.deadlineAt,
    required this.depositAmount,
    this.status = 2,
    required this.createdAt,
  });

  static const statusLabels = ['草稿', '审核中', '招募中', '执行中', '结算中', '已完成', '已取消', '争议中'];
  String get statusLabel => statusLabels[status];
}

/// 任务订单状态机
class OrderStatus {
  static const pending = 10;
  static const executing = 20;
  static const timeout = 31;
  static const userCancel = 32;
  static const submitted = 40;
  static const awaitingReview = 50;
  static const dispute = 55;
  static const approved = 60;
  static const rejected = 70;
  static const settled = 80;
  static const terminated = 81;

  static String label(int s) => switch (s) {
    10 => '待确认',
    20 => '执行中',
    31 => '超时未交付',
    32 => '用户取消',
    40 => '已提交',
    50 => '待商家验收',
    55 => '争议中',
    60 => '已通过',
    70 => '拒绝',
    80 => '已结算',
    81 => '已终止',
    _ => '未知',
  };

  static const flow = [10, 20, 40, 50, 60, 80];
}

class OrderTransition {
  final int from;
  final int to;
  final String operator;
  final String reasonCode;
  final String evidence;
  final DateTime at;
  OrderTransition({
    required this.from,
    required this.to,
    required this.operator,
    required this.reasonCode,
    required this.evidence,
    required this.at,
  });
}

class TaskOrder {
  final String orderId;
  final String taskId;
  final String userId;
  int status;
  int aiCheckAttempts;
  String? submission;
  double? aiCheckScore;
  String? settlementId;
  final List<OrderTransition> history;
  final DateTime createdAt;

  TaskOrder({
    required this.orderId,
    required this.taskId,
    required this.userId,
    this.status = OrderStatus.pending,
    this.aiCheckAttempts = 0,
    this.submission,
    this.aiCheckScore,
    this.settlementId,
    List<OrderTransition>? history,
    required this.createdAt,
  }) : history = history ?? [];
}

class Settlement {
  final String settlementId;
  final String orderId;
  final String userId;
  final double gross;
  final double cashPart;
  final double repayPart;
  final double platformFee;
  final DateTime createdAt;
  final String status; // settled / withdrawn
  Settlement({
    required this.settlementId,
    required this.orderId,
    required this.userId,
    required this.gross,
    required this.cashPart,
    required this.repayPart,
    required this.platformFee,
    required this.createdAt,
    this.status = 'settled',
  });
}

// ───────────────────────── 内容域 D04 ─────────────────────────

/// moderation 0待审 1AI通过 2人工通过 3拒绝 4申诉中；status 0草稿 1已发布 2下架 3删除
class Content {
  final String contentId;
  final String authorId;
  final String authorName;
  final int contentType; // 1图文 2短视频 3长视频 4直播 5音频 6直播回放
  final String title;
  final String body;
  final List<String> tags;
  final bool aiGenerated;
  int moderationStatus;
  String? moderationReason;
  double? aiScore;
  int status;
  int viewCount;
  int likeCount;
  int commentCount;
  int shareCount;
  double revenueAmount;
  double revenueRepayAmount;
  final DateTime publishedAt;
  bool likedByMe;

  Content({
    required this.contentId,
    required this.authorId,
    required this.authorName,
    required this.contentType,
    required this.title,
    required this.body,
    required this.tags,
    this.aiGenerated = false,
    this.moderationStatus = 0,
    this.moderationReason,
    this.aiScore,
    this.status = 1,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.revenueAmount = 0,
    this.revenueRepayAmount = 0,
    required this.publishedAt,
    this.likedByMe = false,
  });

  static const typeLabels = ['', '图文', '短视频', '长视频', '直播', '音频', '直播回放'];
  String get typeLabel => typeLabels[contentType];
  static const modLabels = ['待审', 'AI通过', '人工通过', '拒绝', '申诉中'];
  String get modLabel => modLabels[moderationStatus];
}

// ───────────────────────── AI 智能域 D03 ─────────────────────────

class AgentDef {
  final String code;
  final String name;
  final String enName;
  final String role;
  final String model;
  final int gradientIndex;
  final String emoji;
  final String greeting;
  final List<String> quickPrompts;
  const AgentDef({
    required this.code,
    required this.name,
    required this.enName,
    required this.role,
    required this.model,
    required this.gradientIndex,
    required this.emoji,
    required this.greeting,
    required this.quickPrompts,
  });
}

class ChatMessage {
  final String id;
  final bool fromUser;
  String text;
  final DateTime at;
  final String? model;
  final List<String> toolCalls;
  int feedback; // 0 无 1 赞 -1 踩
  bool streaming;
  ChatMessage({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.at,
    this.model,
    this.toolCalls = const [],
    this.feedback = 0,
    this.streaming = false,
  });
}

// ───────────────────────── 风控 M02 / 运营 M01 ─────────────────────────

class RiskCase {
  final String caseId;
  final String userId;
  final String userName;
  final String ruleCode;
  final String ruleName;
  final String scene;
  final int score;
  final int level; // 1低 2中 3高 4极高
  final String suggestedAction;
  String status; // open / reviewing / resolved / escalated
  String? disposition;
  final DateTime createdAt;
  RiskCase({
    required this.caseId,
    required this.userId,
    required this.userName,
    required this.ruleCode,
    required this.ruleName,
    required this.scene,
    required this.score,
    required this.level,
    required this.suggestedAction,
    this.status = 'open',
    this.disposition,
    required this.createdAt,
  });

  static String levelLabel(int l) => ['', '低 L1', '中 L2', '高 L3', '极高 L4'][l];
}

class RiskRule {
  final String ruleCode;
  final String ruleName;
  final String scene;
  final String expression;
  final int riskScore;
  final String action;
  int status; // 0草稿 1灰度 2生产 3关闭
  int hitCount24h;
  final double fpRate;
  RiskRule({
    required this.ruleCode,
    required this.ruleName,
    required this.scene,
    required this.expression,
    required this.riskScore,
    required this.action,
    this.status = 2,
    this.hitCount24h = 0,
    this.fpRate = 0,
  });
}

class AppNotification {
  final String id;
  final String category; // system / interact / task / finance
  final String title;
  final String body;
  final DateTime at;
  bool read;
  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
  });
}

// ───────────────────────── 接口体系（统一响应 & 日志） ─────────────────────────

class ApiResponse {
  final int code;
  final String message;
  final String traceId;
  final int serverTime;
  final dynamic data;
  final bool idempotencyReplay;
  const ApiResponse({
    required this.code,
    required this.message,
    required this.traceId,
    required this.serverTime,
    this.data,
    this.idempotencyReplay = false,
  });
  bool get ok => code == 0;
}

class ApiLog {
  final String method;
  final String path;
  final String apiId;
  final int code;
  final String message;
  final int latencyMs;
  final String traceId;
  final String requestId;
  final String operator;
  final DateTime at;
  final Map<String, dynamic>? body;
  ApiLog({
    required this.method,
    required this.path,
    required this.apiId,
    required this.code,
    required this.message,
    required this.latencyMs,
    required this.traceId,
    required this.requestId,
    required this.operator,
    required this.at,
    this.body,
  });
}

class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);
  @override
  String toString() => '[$code] $message';
}
