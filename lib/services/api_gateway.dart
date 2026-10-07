import 'dart:math';

import '../models/models.dart';
import 'mock_db.dart';

/// Mock API 网关：模拟 APISIX 网关 + BFF + 微服务集群。
///
/// 严格遵循蓝图 6.2 统一 API 规范：
/// - 统一响应结构 {code, message, trace_id, server_time, data}
/// - 错误码 AABCC 规约（40001 / 40301 / 40302 / 40901 / 42901 / 50301 / 50701 ...）
/// - 幂等键 X-Request-Id（Redis 缓存模拟）
/// - 身份校验链：Token → KYC 等级 → 权限点 → 实体归属 → 二次验证
class ApiGateway {
  ApiGateway._();
  static final ApiGateway instance = ApiGateway._();

  final MockDb db = MockDb.instance;
  final _rand = Random(42);
  final Map<String, ApiResponse> _idempotencyCache = {};
  String? _currentUserId;
  String? _payToken; // 支付密码 5 分钟令牌
  DateTime? _payTokenAt;

  final Map<String, int> _smsCounter = {};

  void setSession(String userId) {
    _currentUserId = userId;
    _payToken = null;
  }

  UserProfile get me {
    final u = db.users[_currentUserId];
    if (u == null) throw ApiException(40301, '未登录/Token 失效');
    return u;
  }

  String _trace() =>
      'tr-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  // ───────────────────────── 核心调用入口 ─────────────────────────

  /// 所有接口统一走 call()。模拟网关延迟、日志、幂等、错误码。
  Future<ApiResponse> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? apiId,
    String? requestId,
    int? kycRequired,
    String? permission,
    bool requirePayToken = false,
    int latencyMs = 0,
  }) async {
    final sw = Stopwatch()..start();
    final trace = _trace();
    final rid = requestId ?? 'req-${_rand.nextInt(1 << 30).toRadixString(16)}';
    final id = apiId ?? 'API-?';

    // L2 网关校验：幂等
    if (requestId != null && _idempotencyCache.containsKey(requestId)) {
      final cached = _idempotencyCache[requestId]!;
      final replay = ApiResponse(
        code: cached.code,
        message: cached.message,
        traceId: trace,
        serverTime: DateTime.now().millisecondsSinceEpoch,
        data: cached.data,
        idempotencyReplay: true,
      );
      _log(method, path, id, replay, sw.elapsedMilliseconds, trace, rid, body);
      return replay;
    }

    await Future.delayed(
      Duration(milliseconds: latencyMs > 0 ? latencyMs : 120 + _rand.nextInt(260)),
    );

    ApiResponse resp;
    try {
      // 身份校验链 (7.4)：登录前可匿名访问的接口白名单（网关 L2 层配置）
      const anonymousPaths = [
        '/v1/auth/login',
        '/v1/auth/register',
        '/v1/auth/sms/send',
        '/v1/auth/password/reset',
        '/v1/auth/risk/challenge',
      ];
      if (_currentUserId == null &&
          !anonymousPaths.any((p) => path.startsWith(p))) {
        throw ApiException(40301, '未登录/Token 失效');
      }
      if (kycRequired != null && me.kycLevel < kycRequired) {
        throw ApiException(40302, 'KYC 等级不足：需要 ${KycLevel.name(kycRequired)}，当前 ${KycLevel.name(me.kycLevel)}');
      }
      if (permission != null && !me.can(permission)) {
        throw ApiException(40303, '权限不足：缺少权限点 $permission');
      }
      if (requirePayToken) {
        if (_payToken == null ||
            DateTime.now().difference(_payTokenAt!).inMinutes >= 5) {
          throw ApiException(40304, '敏感操作需支付密码二次验证（令牌 5 分钟有效）');
        }
      }
      if (_currentUserId != null &&
          me.status == UserStatus.frozen &&
          (path.contains('withdraw') || path.contains('accept'))) {
        throw ApiException(50701, '风控拦截：账户已冻结，请申诉解冻');
      }

      final data = await _route(method, path, body ?? {});
      resp = ApiResponse(
        code: 0,
        message: 'success',
        traceId: trace,
        serverTime: DateTime.now().millisecondsSinceEpoch,
        data: data,
      );
    } on ApiException catch (e) {
      resp = ApiResponse(
        code: e.code,
        message: e.message,
        traceId: trace,
        serverTime: DateTime.now().millisecondsSinceEpoch,
      );
    }

    if (requestId != null && method != 'GET') {
      _idempotencyCache[requestId] = resp;
    }
    _log(method, path, id, resp, sw.elapsedMilliseconds, trace, rid, body);
    return resp;
  }

  void _log(String m, String p, String id, ApiResponse r, int ms, String trace,
      String rid, Map<String, dynamic>? body) {
    db.apiLogs.insert(
      0,
      ApiLog(
        method: m,
        path: p,
        apiId: id,
        code: r.code,
        message: r.idempotencyReplay ? '${r.message} (X-Idempotency-Replay: true)' : r.message,
        latencyMs: ms,
        traceId: trace,
        requestId: rid,
        operator: _currentUserId ?? 'anonymous',
        at: DateTime.now(),
        body: body,
      ),
    );
    if (db.apiLogs.length > 300) db.apiLogs.removeLast();
  }

  // ───────────────────────── 路由表（60+ 接口） ─────────────────────────

  Future<dynamic> _route(String m, String path, Map<String, dynamic> b) async {
    final seg = path.split('?').first.split('/').where((s) => s.isNotEmpty).toList();
    // seg[0] == 'v1'
    final d = seg.length > 1 ? seg[1] : '';
    switch (d) {
      case 'auth':
        return _auth(m, seg, b);
      case 'users':
        return _users(m, seg, b);
      case 'ai':
        return _ai(m, seg, b);
      case 'contents':
        return _contents(m, seg, b);
      case 'tasks':
        return _tasks(m, seg, b);
      case 'settlements':
        return _settlements(m, seg, b);
      case 'debt-cases':
        return _debtCases(m, seg, b);
      case 'repayment-plans':
        return _plans(m, seg, b);
      case 'wallets':
        return _wallets(m, seg, b);
      case 'notifications':
        return _notifications(m, seg, b);
      case 'shop':
        return _shop(m, seg, b);
      case 'debt-points':
        return _debtPoints(m, seg, b);
      case 'clearance':
        return _clearance(m, seg, b);
      case 'bank':
        return _bank(m, seg, b);
      case 'admin':
        return _admin(m, seg, b);
      default:
        throw ApiException(40401, '资源不存在: $path');
    }
  }

  // ───── D02 认证域 ─────
  dynamic _auth(String m, List<String> s, Map<String, dynamic> b) {
    final sub = s.sublist(2).join('/');
    switch (sub) {
      case 'login/sms':
        final uid = b['user_id'] as String?;
        if (uid == null || !db.users.containsKey(uid)) {
          throw ApiException(40401, '账号不存在');
        }
        final code = b['sms_code'] as String? ?? '';
        if (code != '123456') throw ApiException(40001, '短信验证码错误（演示码 123456）');
        _currentUserId = uid;
        _payToken = null;
        return {
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$uid.mock',
          'refresh_token': 'rt-${_rand.nextInt(1 << 30)}',
          'expires_in': 7200,
          'device_bound': true,
          'user': {'uuid': me.uuid, 'nickname': me.nickname, 'kyc_level': me.kycLevel, 'role': me.role.name},
        };
      case 'sms/send':
        final k = b['mobile'] as String? ?? '';
        _smsCounter[k] = (_smsCounter[k] ?? 0) + 1;
        if (_smsCounter[k]! > 10) throw ApiException(42901, '短信发送超限（10 次/天）');
        return {'sent': true, 'ttl': 60, 'hint': '演示环境验证码固定为 123456'};
      case 'logout':
        _currentUserId = null;
        return {'revoked': true};
      case 'kyc/l2/verify':
        final name = b['real_name'] as String? ?? '';
        final idc = b['id_card_no'] as String? ?? '';
        if (!RegExp(r'^[\u4e00-\u9fa5·]{2,30}$').hasMatch(name)) {
          throw ApiException(40001, '参数校验失败：real_name 需 2~30 中文字符');
        }
        if (!RegExp(r'^\d{17}[\dXx]$').hasMatch(idc)) {
          throw ApiException(40001, '参数校验失败：id_card_no 需 18 位（40001-I01）');
        }
        final birthYear = int.tryParse(idc.substring(6, 10)) ?? 2000;
        if (2026 - birthYear < 18) throw ApiException(50601, '合规校验未通过：未成年人禁用金融功能');
        if (idc.endsWith('0000')) throw ApiException(50101, '姓名与身份证不匹配（三要素不一致，冻结 24h 再试）');
        if (me.kycLevel < 2) me.kycLevel = 2;
        return {'kyc_level': me.kycLevel, 'kyc_record_id': db.nextId('KYC'), 'verified_at': DateTime.now().toIso8601String()};
      case 'kyc/l3/liveness':
        if (me.kycLevel < 2) throw ApiException(40901, '状态非法：请先完成 L2 实名认证');
        final score = 92 + _rand.nextInt(8);
        if (me.kycLevel < 3) me.kycLevel = 3;
        return {'kyc_level': me.kycLevel, 'liveness_score': score, 'video_evidence_id': db.nextId('LV')};
      case 'kyc/l4/bank-card':
        if (me.kycLevel < 3) throw ApiException(40901, '状态非法：请先完成 L3 活体认证');
        final card = (b['bank_card_no'] as String? ?? '').replaceAll(' ', '');
        if (!_luhn(card)) throw ApiException(50201, '银行卡验证失败：Luhn 校验不通过（40001-B01）');
        if (me.kycLevel < 4) me.kycLevel = 4;
        return {'kyc_level': me.kycLevel, 'bank': _bankByBin(card), 'micro_deposit': '0.0${1 + _rand.nextInt(9)}'};
      case 'pay-password/verify':
        final pwd = b['pay_password'] as String? ?? '';
        if (pwd != '888888') throw ApiException(40001, '支付密码错误（演示密码 888888）');
        _payToken = 'pt-${_rand.nextInt(1 << 30)}';
        _payTokenAt = DateTime.now();
        return {'auth_token': _payToken, 'expires_in': 300};
      case 'sessions':
        return {
          'list': [
            {'id': 'S1', 'device': 'iPhone 15 Pro · iOS 18', 'city': me.city, 'current': true, 'last_active': '刚刚'},
            {'id': 'S2', 'device': 'Chrome · macOS', 'city': me.city, 'current': false, 'last_active': '2 小时前'},
            {'id': 'S3', 'device': 'Xiaomi 14 · Android 15', 'city': '上海', 'current': false, 'last_active': '3 天前'},
          ]
        };
    }
    if (s.length >= 4 && s[2] == 'sessions' && m == 'DELETE') {
      return {'revoked': s[3]};
    }
    throw ApiException(40401, '资源不存在');
  }

  bool _luhn(String n) {
    if (n.length < 12 || !RegExp(r'^\d+$').hasMatch(n)) return false;
    int sum = 0;
    bool alt = false;
    for (int i = n.length - 1; i >= 0; i--) {
      int d = int.parse(n[i]);
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  String _bankByBin(String c) {
    if (c.startsWith('62')) return '中国银联 · 借记卡';
    if (c.startsWith('4')) return 'Visa';
    if (c.startsWith('5')) return 'MasterCard';
    return '未知发卡行';
  }

  // ───── D01 用户域 ─────
  dynamic _users(String m, List<String> s, Map<String, dynamic> b) {
    final sub = s.sublist(2).join('/');
    switch (sub) {
      case 'me':
        if (m == 'PATCH') {
          final nick = b['nickname'] as String?;
          if (nick != null) {
            if (nick.length < 2 || nick.length > 20) throw ApiException(40001, 'nickname 需 2~20 字符（40001-N01）');
            if (_hasSensitive(nick)) throw ApiException(40001, 'nickname 含敏感词（40001-N01）');
            me.nickname = nick;
          }
        }
        return {'uuid': me.uuid, 'nickname': me.nickname, 'kyc_level': me.kycLevel, 'risk_level': me.riskLevel, 'status': me.status.code, 'city': me.city};
      case 'me/debt-profile':
        final p = db.debtProfiles[me.userId];
        if (p == null) throw ApiException(40401, '该角色无负债画像');
        return {'total_debt_amount': p.totalDebt, 'debt_count': p.debtCount, 'multi_borrow_index': p.multiBorrowIndex, 'repayment_willingness': p.repaymentWillingness};
      case 'me/debt-profile/import':
        return _importDebt(b);
      case 'me/value-cloud':
        return {'value_score': me.valueScore, 'light_points': me.lightPoints, 'redeem_progress_pct': me.redeemProgressPct, 'capability_tags': me.capabilityTags};
      case 'me/value-cloud/recompute':
        me.valueScore += 15 + _rand.nextInt(40);
        return {'value_score': me.valueScore, 'recomputed_at': DateTime.now().toIso8601String(), 'embedding_dims': 1536};
      case 'me/growth':
        return {'level': me.level, 'exp': me.exp, 'light_points': me.lightPoints};
      case 'me/privacy':
        return {'fields': ['birthday', 'city', 'debt_profile', 'value_cloud']};
      case 'me/deactivate':
        me.status = UserStatus.deactivating;
        return {'cooling_days': 15, 'revocable': true};
    }
    throw ApiException(40401, '资源不存在');
  }

  bool _hasSensitive(String t) => RegExp(r'征信修复|内部渠道|加微|VX|上岸包过').hasMatch(t);

  dynamic _importDebt(Map<String, dynamic> b) {
    final source = b['source'] as String? ?? 'user_manual';
    if (source == 'pboc_credit' && b['consent'] != true) {
      throw ApiException(50801, 'Consent 未授权：征信查询需用户单独同意');
    }
    final creditor = b['creditor'] as String? ?? '手动录入债权方';
    final amount = (b['amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) throw ApiException(40001, 'amount 必须 > 0（40001-A01）');
    final type = DebtType.values.firstWhere((t) => t.name == (b['debt_type'] ?? 'privateDebt'), orElse: () => DebtType.privateDebt);
    final c = DebtCase(
      caseId: db.nextId('DC'),
      userId: me.userId,
      creditorName: creditor,
      caseNo: '${source.toUpperCase()}-${db.nextId('')}',
      debtType: type,
      principal: amount,
      interest: 0,
      penalty: 0,
      outstanding: amount,
      overdueDays: (b['overdue_days'] as num?)?.toInt() ?? 0,
      importSource: source,
      consentId: 'CS-${_rand.nextInt(1 << 20).toRadixString(16)}',
    );
    db.debtCases.add(c);
    final p = db.debtProfiles.putIfAbsent(me.userId, () => DebtProfile());
    p.totalDebt += amount;
    p.debtCount += 1;
    p.privateDebt += type == DebtType.privateDebt ? amount : 0;
    return {'case_id': c.caseId, 'consent_id': c.consentId, 'webhook': 'DEBT.CASE.IMPORTED'};
  }

  // ───── D06 还债与账户域 ─────
  dynamic _debtCases(String m, List<String> s, Map<String, dynamic> b) {
    if (s.length == 2) {
      return {'list': db.debtCases.where((c) => c.userId == me.userId).map((c) => c.caseId).toList()};
    }
    if (s[2] == 'import') return _importDebt(b);
    final c = db.debtCases.firstWhere((c) => c.caseId == s[2], orElse: () => throw ApiException(40401, '案件不存在'));
    final tenantOk = me.role.isBank && c.creditorName == me.orgName;
    if (c.userId != me.userId && !me.role.isAdmin && !tenantOk) throw ApiException(40303, '业务实体归属校验失败：非本人/本机构案件');
    return {'case_id': c.caseId, 'outstanding': c.outstanding};
  }

  dynamic _plans(String m, List<String> s, Map<String, dynamic> b) {
    if (s.length >= 4 && s[2] == 'ai' && s[3] == 'generate') {
      final c = db.debtCases.firstWhere((c) => c.caseId == b['case_id'], orElse: () => throw ApiException(40401, '案件不存在'));
      if (c.userId != me.userId) throw ApiException(40303, '非本人案件');
      final p = db.debtProfiles[me.userId] ?? DebtProfile();
      final out = c.outstanding;
      final plans = <RepaymentPlan>[
        RepaymentPlan(planId: db.nextId('RP'), caseId: c.caseId, planType: 'installment', title: '稳健 · 36 期停息挂账', summary: '申请停息挂账，罚息全免 ¥${c.penalty.toStringAsFixed(0)}，本息 36 期均摊。月供占收入 ${((out - c.penalty) / 36 / max(p.monthlyIncome, 1) * 100).toStringAsFixed(0)}%，压力最低。', totalAmount: out - c.penalty, reductionAmount: c.penalty, periods: 36, monthlyAmount: (out - c.penalty) / 36, model: 'GPT-4o', status: 1),
        RepaymentPlan(planId: db.nextId('RP'), caseId: c.caseId, planType: 'mixed', title: '进取 · 24 期 + 流量还债 60%', summary: '24 期分期，同时把任务/内容收益的 60% 自动划入。按你近 30 天均收入 ¥${(me.valueScore * 0.35).toStringAsFixed(0)} 推算，可提前 5~7 期结清。', totalAmount: out - c.penalty * 0.5, reductionAmount: c.penalty * 0.5, periods: 24, monthlyAmount: (out - c.penalty * 0.5) / 24, model: 'DeepSeek-V3', status: 1),
        RepaymentPlan(planId: db.nextId('RP'), caseId: c.caseId, planType: 'lump_sum', title: '决断 · 一次性结清（本金 8 折）', summary: '${c.bucket} 桶资产，债权方通常接受 75~85% 本金一次性结清。需筹措 ¥${(c.principal * 0.8).toStringAsFixed(0)}，可结合 AMC 匹配。', totalAmount: c.principal * 0.8, reductionAmount: out - c.principal * 0.8, periods: 1, monthlyAmount: c.principal * 0.8, model: 'Claude 3.5 Sonnet', status: 1),
      ];
      db.plans.removeWhere((p) => p.caseId == c.caseId && p.status <= 1);
      db.plans.addAll(plans);
      c.negotiationStatus = 1;
      return {'plans': plans.map((p) => p.planId).toList(), 'apr_check': 'LPR×4 合规 ✓', 'agent': 'AG-01 DebtPlanner'};
    }
    if (s.length >= 4 && s[3] == 'confirm') {
      final p = db.plans.firstWhere((p) => p.planId == s[2], orElse: () => throw ApiException(40401, '方案不存在'));
      if (p.status != 1) throw ApiException(40901, '资源冲突：方案状态 ${p.statusLabel} 不可确认');
      p.status = 2;
      p.userConfirmedAt = DateTime.now();
      // 模拟债权方 Webhook 回调确认
      Future.delayed(const Duration(milliseconds: 1500), () {
        p.status = 3;
        p.creditorConfirmedAt = DateTime.now();
        final c = db.debtCases.firstWhere((c) => c.caseId == p.caseId);
        c.negotiationStatus = 3;
        c.planId = p.planId;
        for (final o in db.plans.where((o) => o.caseId == p.caseId && o.planId != p.planId && o.status == 1)) {
          o.status = 6;
        }
        db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'REPAYMENT.PLAN.CONFIRMED · 债权方已确认', body: '${c.creditorName} 已确认方案「${p.title}」，首期将于下月 5 日自动扣款。', at: DateTime.now()));
      });
      return {'plan_id': p.planId, 'status': p.status, 'webhook': 'REPAYMENT.PLAN.CONFIRMED (pending creditor)', 'e_sign': 'e签宝合同已生成'};
    }
    if (s.length >= 4 && s[3] == 'execute') {
      final p = db.plans.firstWhere((p) => p.planId == s[2], orElse: () => throw ApiException(40401, '方案不存在'));
      if (p.status != 3) throw ApiException(40901, '资源冲突：方案未在执行中');
      final amt = p.monthlyAmount;
      if (me.walletBalance < amt) throw ApiException(50301, '余额不足：需 ¥${amt.toStringAsFixed(2)}，当前 ¥${me.walletBalance.toStringAsFixed(2)}');
      me.walletBalance -= amt;
      p.paidPeriods += 1;
      final c = db.debtCases.firstWhere((c) => c.caseId == p.caseId);
      c.outstanding = max(0, c.outstanding - amt);
      c.cashPaid += amt;
      _postLedger('repay', '${p.planId}-P${p.paidPeriods}', [
        ('用户 ${me.userId} 钱包', 'D', amt, me.walletBalance),
        ('用户 ${me.userId} 债务本金', 'C', amt, c.outstanding),
      ]);
      db.walletTxs.insert(0, WalletTx(txId: db.nextId('TX'), type: 'repay', title: '还款方案 ${p.planId} 第 ${p.paidPeriods} 期手动还款', amount: -amt, createdAt: DateTime.now()));
      _bumpRedeem(amt);
      if (p.paidPeriods >= p.periods || c.outstanding <= 0.005) {
        p.status = 4;
        _issueCertificate(c);
      }
      db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'REPAYMENT.SUCCESS · 第 ${p.paidPeriods} 期还款成功', body: '¥${amt.toStringAsFixed(2)} 已划入 ${c.creditorName}，剩余 ${p.periods - p.paidPeriods} 期。', at: DateTime.now()));
      return {'paid_periods': p.paidPeriods, 'outstanding': c.outstanding, 'receipt_id': db.nextId('RCPT'), 'webhook': 'REPAYMENT.SUCCESS'};
    }
    throw ApiException(40401, '资源不存在');
  }

  void _bumpRedeem(double amt) {
    final p = db.debtProfiles[me.userId];
    if (p == null) return;
    final total = p.weeklySnapshots.isNotEmpty ? p.weeklySnapshots.first : p.totalDebt;
    me.carbonDebtSaved += amt;
    p.totalDebt = max(0, p.totalDebt - amt);
    me.redeemProgressPct = (me.carbonDebtSaved / max(total, 1) * 100).clamp(0, 100);
    me.exp += (amt / 10).round();
    while (me.exp >= me.level * 400) {
      me.exp -= me.level * 400;
      me.level += 1;
    }
  }

  void _postLedger(String bizType, String ref, List<(String, String, double, double)> lines) {
    final tx = db.nextId('TX');
    double d = 0, c = 0;
    for (final l in lines) {
      l.$2 == 'D' ? d += l.$3 : c += l.$3;
    }
    if ((d - c).abs() > 0.005) throw ApiException(50001, '借贷不平衡：D=$d C=$c，拒绝入账');
    for (final l in lines) {
      db.ledger.insert(0, LedgerEntry(entryId: db.nextId('LE'), txId: tx, account: l.$1, direction: l.$2, amount: l.$3, businessType: bizType, businessRefId: ref, balanceAfter: l.$4, opType: 1, createdAt: DateTime.now()));
    }
  }

  dynamic _wallets(String m, List<String> s, Map<String, dynamic> b) {
    final sub = s.sublist(2).join('/');
    switch (sub) {
      case 'me':
        return {'balance': me.walletBalance, 'frozen': me.walletFrozen, 'light_points': me.lightPoints, 'daily_limit': KycLevel.limits[me.kycLevel]};
      case 'recharge':
        final amt = (b['amount'] as num?)?.toDouble() ?? 0;
        if (amt <= 0 || amt > 50000) throw ApiException(40001, 'amount 需 0 < x ≤ 50000（40001-A01）');
        me.walletBalance += amt;
        _postLedger('recharge', db.nextId('PAY'), [
          ('支付通道待清算 · ${b['channel'] ?? 'wechat'}', 'D', amt, 0),
          ('用户 ${me.userId} 钱包', 'C', amt, me.walletBalance),
        ]);
        db.walletTxs.insert(0, WalletTx(txId: db.nextId('TX'), type: 'recharge', title: '${_channelName(b['channel'])}充值', amount: amt, createdAt: DateTime.now()));
        return {'balance': me.walletBalance, 'channel': b['channel'], 'webhook': 'PAYMENT.SUCCESS'};
      case 'withdraw':
        final amt = (b['amount'] as num?)?.toDouble() ?? 0;
        if (amt <= 0) throw ApiException(40001, 'amount 必须 > 0');
        final limit = KycLevel.limits[me.kycLevel];
        if (amt > limit) throw ApiException(50302, '超出限额：${KycLevel.name(me.kycLevel)} 单日限额 ¥$limit');
        if (amt > me.walletBalance) throw ApiException(50301, '余额不足');
        if (amt >= 5000 && me.riskLevel >= 1) throw ApiException(50701, '风控拦截：大额提现 + 中风险用户，转人工电话核实（T+1）');
        me.walletBalance -= amt;
        _postLedger('withdraw', db.nextId('WD'), [
          ('用户 ${me.userId} 钱包', 'D', amt, me.walletBalance),
          ('银行存管出款账户', 'C', amt, 0),
        ]);
        db.walletTxs.insert(0, WalletTx(txId: db.nextId('TX'), type: 'withdraw', title: '提现至银行卡 (尾号 ${b['card_tail'] ?? '6621'})', amount: -amt, createdAt: DateTime.now(), status: 'pending'));
        return {'balance': me.walletBalance, 'arrival': 'T+1', 'fee': 0};
      case 'transactions':
        return {'list': db.walletTxs.length, 'pagination': {'page': 1, 'size': 20, 'has_more': false}};
      case 'light-points/redeem':
        final pts = (b['points'] as num?)?.toInt() ?? 0;
        if (pts <= 0 || pts % 100 != 0) throw ApiException(40001, '光芒值需为 100 的整数倍');
        if (pts > me.lightPoints) throw ApiException(50301, '光芒值不足');
        final amt = pts / 100.0;
        me.lightPoints -= pts;
        final ref = db.nextId('LR');
        final dp = _issueDebtPoints(me.userId, DebtPointSource.lightPoints, amt, amt, ref, '光芒值兑换 · $pts ✦ → ${amt.toStringAsFixed(1)} DP');
        _postLedger('light_redeem', ref, [
          ('平台待结算账户', 'D', amt, 0),
          ('债务积分现金备付金 · ${me.userId}', 'C', amt, 0),
        ]);
        return {'redeemed_points': pts, 'debt_points_issued': amt, 'dp_batch_id': dp.batchId, 'rate': '100 光芒值 = 1 DP = ¥1 抵债'};
    }
    throw ApiException(40401, '资源不存在');
  }

  String _channelName(dynamic c) => switch (c) {
    'alipay' => '支付宝',
    'unionpay' => '云闪付',
    'ecny' => '数字人民币',
    _ => '微信',
  };

  // ───── D05 任务域 ─────
  dynamic _tasks(String m, List<String> s, Map<String, dynamic> b) {
    if (s.length == 2 && m == 'POST') {
      final reward = (b['reward_amount'] as num?)?.toDouble() ?? 0;
      final maxP = (b['max_participants'] as num?)?.toInt() ?? 1;
      if (reward <= 0) throw ApiException(40001, 'reward_amount 必须 > 0');
      final deposit = reward * maxP;
      if (me.walletBalance < deposit) throw ApiException(50301, '余额不足：发布任务需缴纳保证金 ¥${deposit.toStringAsFixed(0)}（奖励 × 人数）');
      me.walletBalance -= deposit;
      me.walletFrozen += deposit;
      final t = Task(
        taskId: db.nextId('T'),
        publisherId: me.userId,
        publisherName: me.nickname,
        taskType: b['task_type'] ?? '内容创作',
        title: b['title'] ?? '未命名任务',
        description: b['description'] ?? '',
        rewardAmount: reward,
        splitPolicy: SplitPolicy(cashPct: (b['cash_pct'] as num?)?.toInt() ?? 40, repayPct: (b['repay_pct'] as num?)?.toInt() ?? 60),
        maxParticipants: maxP,
        kycLevelRequired: (b['kyc_level_required'] as num?)?.toInt() ?? 2,
        valueScoreMin: (b['value_score_min'] as num?)?.toInt() ?? 0,
        targetTags: List<String>.from(b['target_tags'] ?? []),
        deadlineAt: DateTime.now().add(const Duration(days: 14)),
        depositAmount: deposit,
        status: 1,
        createdAt: DateTime.now(),
      );
      db.tasks.insert(0, t);
      Future.delayed(const Duration(seconds: 2), () => t.status = 2); // 运营审核自动通过
      return {'task_id': t.taskId, 'deposit_amount': deposit, 'audit_status': 0};
    }
    if (s.length == 3 && s[2] == 'market') {
      return {'list': db.tasks.where((t) => t.status == 2).length, 'filters': b};
    }
    if (s.length >= 4 && s[2] == 'ai' && s[3] == 'recommend') {
      final tags = me.capabilityTags.toSet();
      final scored = db.tasks.where((t) => t.status == 2).map((t) {
        final overlap = t.targetTags.where(tags.contains).length;
        final score = 60 + overlap * 12 + (me.valueScore >= t.valueScoreMin ? 10 : -20) + (me.kycLevel >= t.kycLevelRequired ? 5 : -30);
        return (t.taskId, score.clamp(0, 99));
      }).toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
      return {'recommendations': scored.map((e) => {'task_id': e.$1, 'match_score': e.$2}).toList(), 'agent': 'AG-03 TaskMatcher', 'model': 'Qwen-Max'};
    }
    final t = db.tasks.firstWhere((t) => t.taskId == s[2], orElse: () => throw ApiException(40401, '任务不存在'));
    if (s.length == 3) return {'task_id': t.taskId, 'status': t.status};
    switch (s[3]) {
      case 'accept':
        if (t.status != 2) throw ApiException(40901, '资源冲突：任务状态「${t.statusLabel}」不可接单');
        if (me.kycLevel < t.kycLevelRequired) throw ApiException(40302, 'KYC 等级不足：任务要求 ${KycLevel.name(t.kycLevelRequired)}');
        if (me.valueScore < t.valueScoreMin) throw ApiException(50701, '风控拦截：价值分 ${me.valueScore.toStringAsFixed(0)} < 任务要求 ${t.valueScoreMin}');
        if (t.currentParticipants >= t.maxParticipants) throw ApiException(40901, '任务名额已满');
        if (db.orders.any((o) => o.taskId == t.taskId && o.userId == me.userId && o.status < 60)) throw ApiException(40901, '你已接过该任务');
        final active = db.orders.where((o) => o.userId == me.userId && o.status == OrderStatus.executing).length;
        if (active >= 5) throw ApiException(42901, '同时执行中订单上限 5 个');
        final o = TaskOrder(orderId: db.nextId('TO'), taskId: t.taskId, userId: me.userId, createdAt: DateTime.now());
        o.history.add(OrderTransition(from: 0, to: 10, operator: me.userId, reasonCode: 'ACCEPT', evidence: 'API-T-004', at: DateTime.now()));
        o.status = OrderStatus.executing;
        o.history.add(OrderTransition(from: 10, to: 20, operator: 'SYSTEM', reasonCode: 'AUTO_CONFIRM', evidence: '商家开启自动确认', at: DateTime.now()));
        t.currentParticipants += 1;
        db.orders.insert(0, o);
        return {'order_id': o.orderId, 'status': o.status, 'deadline_at': t.deadlineAt.toIso8601String()};
      case 'orders':
        final o = db.orders.firstWhere((o) => o.orderId == s[4], orElse: () => throw ApiException(40401, '订单不存在'));
        switch (s[5]) {
          case 'submit':
            if (o.userId != me.userId) throw ApiException(40303, '非本人订单');
            if (o.status != OrderStatus.executing) throw ApiException(40901, '状态非法：${OrderStatus.label(o.status)} 不可提交');
            final sub = (b['submission'] as String? ?? '').trim();
            if (sub.length < 6) throw ApiException(40001, 'submission 至少 6 字符');
            o.submission = sub;
            o.aiCheckAttempts += 1;
            o.status = OrderStatus.submitted;
            o.history.add(OrderTransition(from: 20, to: 40, operator: me.userId, reasonCode: 'SUBMIT', evidence: 'API-T-005', at: DateTime.now()));
            // AI 初验
            final suspicious = RegExp(r'搬运|复制|test|测试').hasMatch(sub);
            final score = suspicious ? 42.0 + _rand.nextInt(20) : 85.0 + _rand.nextInt(14);
            o.aiCheckScore = score;
            if (score < 60) {
              if (o.aiCheckAttempts >= 3) {
                o.status = OrderStatus.rejected;
                o.history.add(OrderTransition(from: 40, to: 70, operator: 'AI', reasonCode: 'AI_CHECK_FAIL_3X', evidence: '原创性 $score', at: DateTime.now()));
                return {'status': o.status, 'ai_score': score, 'message': 'AI 初验 3 次不通过，订单终止'};
              }
              o.status = OrderStatus.executing;
              o.history.add(OrderTransition(from: 40, to: 20, operator: 'AI', reasonCode: 'AI_CHECK_FAIL', evidence: '原创性 ${score.toStringAsFixed(1)}（<60），退回修改 ${o.aiCheckAttempts}/3', at: DateTime.now()));
              return {'status': o.status, 'ai_score': score, 'message': 'AI 初验不通过，已退回执行中（${o.aiCheckAttempts}/3）'};
            }
            o.status = OrderStatus.awaitingReview;
            o.history.add(OrderTransition(from: 40, to: 50, operator: 'AI', reasonCode: 'AI_CHECK_PASS', evidence: '原创性 ${score.toStringAsFixed(1)} / 搬运检测通过', at: DateTime.now()));
            return {'status': o.status, 'ai_score': score, 'sla': '商家 72h 内未响应自动通过'};
          case 'review':
            if (t.publisherId != me.userId && !me.role.isAdmin) throw ApiException(40303, '权限不足：仅任务发布方可验收');
            if (o.status != OrderStatus.awaitingReview && o.status != OrderStatus.dispute) throw ApiException(40901, '状态非法：${OrderStatus.label(o.status)}');
            final approve = b['approve'] == true;
            if (!approve) {
              o.status = OrderStatus.dispute;
              o.history.add(OrderTransition(from: 50, to: 55, operator: me.userId, reasonCode: 'MERCHANT_REJECT', evidence: b['reason'] ?? '', at: DateTime.now()));
              return {'status': o.status, 'webhook': 'TASK.ORDER.DISPUTED', 'arbitration': '平台 48h 内仲裁'};
            }
            o.status = OrderStatus.approved;
            o.history.add(OrderTransition(from: 50, to: 60, operator: me.userId, reasonCode: 'MERCHANT_APPROVE', evidence: 'API-T-006', at: DateTime.now()));
            return _settle(t, o);
          case 'arbitrate':
            if (!me.role.isAdmin) throw ApiException(40303, '权限不足');
            if (o.status != OrderStatus.dispute) throw ApiException(40901, '非争议状态');
            if (b['approve'] == true) {
              o.status = OrderStatus.approved;
              o.history.add(OrderTransition(from: 55, to: 60, operator: me.userId, reasonCode: 'ARBITRATION_APPROVE', evidence: b['reason'] ?? '', at: DateTime.now()));
              return _settle(t, o);
            }
            o.status = OrderStatus.rejected;
            o.history.add(OrderTransition(from: 55, to: 70, operator: me.userId, reasonCode: 'ARBITRATION_REJECT', evidence: b['reason'] ?? '', at: DateTime.now()));
            o.status = OrderStatus.terminated;
            o.history.add(OrderTransition(from: 70, to: 81, operator: 'SYSTEM', reasonCode: 'DEPOSIT_RELEASED', evidence: '保证金退回商家', at: DateTime.now()));
            return {'status': o.status};
          case 'dispute':
            if (o.status != OrderStatus.awaitingReview && o.status != OrderStatus.rejected) throw ApiException(40901, '状态非法');
            o.status = OrderStatus.dispute;
            o.history.add(OrderTransition(from: 50, to: 55, operator: me.userId, reasonCode: 'USER_DISPUTE', evidence: b['reason'] ?? '', at: DateTime.now()));
            return {'status': o.status, 'webhook': 'TASK.ORDER.DISPUTED'};
        }
    }
    throw ApiException(40401, '资源不存在');
  }

  dynamic _settle(Task t, TaskOrder o) {
    final worker = db.users[o.userId]!;
    final gross = t.rewardAmount;
    final fee = gross * t.splitPolicy.platformFeePct / 100;
    final net = gross - fee;
    final cash = net * t.splitPolicy.cashPct / (t.splitPolicy.cashPct + t.splitPolicy.repayPct);
    final repay = net - cash;
    final publisher = db.users[t.publisherId];
    if (publisher != null) publisher.walletFrozen = max(0, publisher.walletFrozen - gross);
    worker.walletBalance += cash;
    worker.lightPoints += (gross * 10).round();
    // 流量还债部分 → 发行债务积分（现金背书 100%），由用户选择转交银行清缴
    DebtPointBatch? dp;
    if (repay > 0) {
      dp = _issueDebtPoints(worker.userId, DebtPointSource.task, repay, repay, o.orderId, '任务结算 · ${t.title}（${t.splitPolicy.repayPct}%）');
    }
    final st = Settlement(settlementId: db.nextId('ST'), orderId: o.orderId, userId: worker.userId, gross: gross, cashPart: cash, repayPart: repay, platformFee: fee, createdAt: DateTime.now());
    db.settlements.insert(0, st);
    o.settlementId = st.settlementId;
    _postLedger('commission', o.orderId, [
      ('商家 ${t.publisherId} 保证金账户', 'D', gross, publisher?.walletFrozen ?? 0),
      ('用户 ${worker.userId} 钱包', 'C', cash, worker.walletBalance),
      ('债务积分现金备付金 · ${worker.userId}', 'C', repay, 0),
      ('平台服务费收入', 'C', fee, 0),
    ]);
    db.walletTxs.insert(0, WalletTx(txId: st.settlementId, type: 'task_income', title: '任务结算 · ${t.title} (提现 ${t.splitPolicy.cashPct}%)', amount: cash, createdAt: DateTime.now()));
    if (repay > 0) {
      db.walletTxs.insert(0, WalletTx(txId: '${st.settlementId}R', type: 'debt_points', title: '流量还债 · 转入债务积分 +${repay.toStringAsFixed(1)} DP (${t.splitPolicy.repayPct}%)', amount: 0, createdAt: DateTime.now()));
    }
    o.status = OrderStatus.settled;
    o.history.add(OrderTransition(from: 60, to: 80, operator: 'SYSTEM', reasonCode: 'SETTLED', evidence: '${st.settlementId} 复式记账 4 分录', at: DateTime.now()));
    if (db.orders.where((x) => x.taskId == t.taskId && x.status < 60).isEmpty && t.currentParticipants >= t.maxParticipants) t.status = 5;
    db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'task', title: 'TASK.ORDER.COMPLETED · 任务已结算', body: '「${t.title}」结算 ¥${gross.toStringAsFixed(0)}：+${repay.toStringAsFixed(1)} 债务积分（可转交银行清缴），¥${cash.toStringAsFixed(1)} 到账钱包，+${(gross * 10).round()} 光芒值。', at: DateTime.now()));
    return {'status': o.status, 'settlement_id': st.settlementId, 'gross': gross, 'cash': cash, 'debt_points_issued': repay, 'dp_batch_id': dp?.batchId, 'platform_fee': fee, 'webhooks': ['TASK.ORDER.COMPLETED', 'SETTLEMENT.CREATED', 'DEBT_POINTS.ISSUED']};
  }

  dynamic _settlements(String m, List<String> s, Map<String, dynamic> b) {
    return {'list': db.settlements.where((x) => x.userId == me.userId).length};
  }

  // ───── D04 内容域 ─────
  dynamic _contents(String m, List<String> s, Map<String, dynamic> b) {
    if (s.length == 2 && m == 'POST') {
      final title = (b['title'] as String? ?? '').trim();
      final body = (b['body'] as String? ?? '').trim();
      if (title.isEmpty || title.length > 120) throw ApiException(40001, 'title 需 1~120 字符');
      if (body.length < 10) throw ApiException(40001, 'body 至少 10 字符（40001-C01）');
      final text = '$title $body';
      final aiGen = b['ai_generated'] == true;
      // AI 初审 12 项（简化）
      double score = 95;
      String? reason;
      if (_hasSensitive(text) || RegExp(r'加我|微信|VX|QQ').hasMatch(text)) {
        score = 15;
        reason = '诱导跳转 / 引流联系方式';
      } else if (RegExp(r'催收|停息|逾期|征信|协商').hasMatch(text)) {
        score = 82;
        reason = '涉及金融/负债敏感类目，转人工复审';
      }
      if (!aiGen && RegExp(r'AI ?(生成|创作|写)').hasMatch(text)) {
        score = min(score, 70);
        reason = 'AI 生成未标注';
      }
      final c = Content(
        contentId: db.nextId('C'),
        authorId: me.userId,
        authorName: me.nickname,
        contentType: (b['content_type'] as num?)?.toInt() ?? 1,
        title: title,
        body: body,
        tags: List<String>.from(b['tags'] ?? []),
        aiGenerated: aiGen,
        aiScore: score,
        moderationStatus: score >= 90 ? 1 : (score < 30 ? 3 : 0),
        moderationReason: reason,
        status: score >= 90 ? 1 : 0,
        publishedAt: DateTime.now(),
      );
      db.contents.insert(0, c);
      if (c.moderationStatus == 3) {
        db.riskCases.insert(0, RiskCase(caseId: db.nextId('RC'), userId: me.userId, userName: me.nickname, ruleCode: 'CNT-INDUCE-003', ruleName: '内容含引流联系方式', scene: 'content', score: 96, level: 3, suggestedAction: 'block + review', createdAt: DateTime.now()));
      }
      return {'content_id': c.contentId, 'moderation_status': c.moderationStatus, 'ai_score': score, 'reason': reason, 'sla': 'AI ≤ 5s / 人工 ≤ 30min'};
    }
    if (s.length == 4 && s[2] == 'feed') {
      return {'feed': s[3], 'count': db.contents.where((c) => c.status == 1).length};
    }
    final c = db.contents.firstWhere((c) => c.contentId == s[2], orElse: () => throw ApiException(40401, '内容不存在'));
    if (s.length == 3) {
      if (m == 'DELETE') {
        if (c.authorId != me.userId) throw ApiException(40303, '非本人内容');
        c.status = 3;
        return {'deleted': true};
      }
      c.viewCount += 1;
      return {'content_id': c.contentId, 'view_count': c.viewCount};
    }
    switch (s[3]) {
      case 'like':
        c.likedByMe = !c.likedByMe;
        c.likeCount += c.likedByMe ? 1 : -1;
        return {'liked': c.likedByMe, 'like_count': c.likeCount};
      case 'share':
        c.shareCount += 1;
        return {'url': 'https://xg.cloud/s/${c.contentId}?utm_source=${me.userId}&utm_medium=${c.contentType}&sig=${_rand.nextInt(1 << 20).toRadixString(16)}', 'attribution_window': '点击 7d / 转化 30d'};
      case 'comments':
        c.commentCount += 1;
        return {'comment_id': db.nextId('CM')};
      case 'appeal':
        if (c.moderationStatus != 3) throw ApiException(40901, '仅被拒内容可申诉');
        c.moderationStatus = 4;
        return {'moderation_status': 4};
      case 'revenue':
        return {'revenue_amount': c.revenueAmount, 'revenue_repay_amount': c.revenueRepayAmount};
    }
    throw ApiException(40401, '资源不存在');
  }

  // ───── D03 AI 域 ─────
  dynamic _ai(String m, List<String> s, Map<String, dynamic> b) {
    if (s[2] == 'feedback') return {'recorded': true, 'prompt_iteration_queue': true};
    if (s[2] == 'moderation') return {'safe': !_hasSensitive(b['text'] ?? '')};
    if (s[2] == 'agents' && s.length >= 5 && s[4] == 'chat') {
      final text = (b['message'] as String? ?? '').trim();
      if (text.isEmpty) throw ApiException(40001, 'message 不能为空');
      if (RegExp(r'ignore previous|忽略.*指令|system prompt', caseSensitive: false).hasMatch(text)) {
        throw ApiException(50701, '风控拦截：检测到 Prompt 注入（AI-INJECT-007）');
      }
      return {'accepted': true};
    }
    throw ApiException(40401, '资源不存在');
  }

  // ───── 债务积分池：所有平台价值创造统一汇入 ─────
  DebtPointBatch _issueDebtPoints(String userId, DebtPointSource src, double face, double cash, String ref, String title, {String? ruleSnapshot}) {
    final batch = DebtPointBatch(batchId: db.nextId('DP'), userId: userId, source: src, faceValue: face, cashBacked: cash, refId: ref, title: title, createdAt: DateTime.now(), ruleSnapshot: ruleSnapshot);
    db.debtPoints.insert(0, batch);
    return batch;
  }

  double availablePoints(String userId) => db.debtPoints.where((b) => b.userId == userId).fold(0.0, (a, b) => a + b.remaining);

  // ───── 平债倍率规则引擎（运营可配：品类基础 + 信用加成，受全局上限） ─────
  OffsetQuote quoteOffset(Product sku, UserProfile u) {
    final live = db.offsetRules.where((r) => r.status == 2 || r.status == 1).toList();
    final cat = live.where((r) => r.ruleType == 'category' && r.category == sku.category).firstOrNull;
    final tier = live.where((r) => r.ruleType == 'credit_tier' && u.creditScore >= (r.creditMin ?? 0) && u.creditScore <= (r.creditMax ?? 9999)).firstOrNull;
    final cap = live.where((r) => r.ruleType == 'global_cap').firstOrNull;
    final base = cat?.value ?? sku.offsetMultiplier.toDouble();
    final bonus = tier?.value ?? 0;
    final capV = cap?.value ?? 99;
    final fin = min(base + bonus, capV);
    final applied = [if (cat != null) cat.ruleId, if (tier != null) tier.ruleId, if (cap != null && base + bonus > capV) cap.ruleId];
    return OffsetQuote(baseMultiplier: base, creditBonus: bonus, cap: capV, finalMultiplier: fin, appliedRules: applied);
  }

  // ───── D07 商城 · 消费平债 ─────
  dynamic _shop(String m, List<String> s, Map<String, dynamic> b) {
    if (s.length == 3 && s[2] == 'products') {
      return {'list': MockDb.products.length, 'offset_rule': '平台利润 × 倍率 = 抵债积分，现金背书 = 平台利润'};
    }
    if (s.length == 3 && s[2] == 'quote') {
      final sku = MockDb.products.firstWhere((p) => p.skuId == b['sku_id'], orElse: () => throw ApiException(40401, '商品不存在'));
      final q = quoteOffset(sku, me);
      return {'multiplier': q.finalMultiplier, 'offset_points': sku.platformMargin * q.finalMultiplier, 'rules': q.appliedRules, 'explain': q.explain};
    }
    if (s.length == 3 && s[2] == 'orders' && m == 'POST') {
      final sku = MockDb.products.firstWhere((p) => p.skuId == b['sku_id'], orElse: () => throw ApiException(40401, '商品不存在'));
      final channel = b['channel'] as String? ?? 'wallet';
      if (channel == 'wallet') {
        if (me.walletBalance < sku.price) throw ApiException(50301, '余额不足：需 ¥${sku.price}，当前 ¥${me.walletBalance.toStringAsFixed(2)}');
        me.walletBalance -= sku.price;
      }
      final q = quoteOffset(sku, me);
      final offset = double.parse((sku.platformMargin * q.finalMultiplier).toStringAsFixed(2));
      for (final rid in q.appliedRules) {
        db.offsetRules.firstWhere((r) => r.ruleId == rid).hitCount += 1;
      }
      final orderId = db.nextId('SO');
      final batch = _issueDebtPoints(me.userId, DebtPointSource.consumption, offset, sku.platformMargin, orderId, '消费平债 · ${sku.name}（利润 ¥${sku.platformMargin} × ${q.finalMultiplier.toStringAsFixed(1)}）', ruleSnapshot: '${q.explain} · ${q.appliedRules.join(',')}');
      db.shopOrders.insert(0, ShopOrder(orderId: orderId, userId: me.userId, skuId: sku.skuId, name: sku.name, price: sku.price, platformMargin: sku.platformMargin, offsetAmount: offset, dpBatchId: batch.batchId, createdAt: DateTime.now()));
      // 复式记账：商品款入商家，平台利润转入「债务积分现金备付金」
      _postLedger('consumption_offset', orderId, [
        (channel == 'wallet' ? '用户 ${me.userId} 钱包' : '支付通道待清算 · ${_channelName(channel)}', 'D', sku.price, me.walletBalance),
        ('商家 ${sku.merchant} 应付', 'C', sku.price - sku.platformMargin, 0),
        ('债务积分现金备付金 · ${me.userId}', 'C', sku.platformMargin, 0),
      ]);
      db.walletTxs.insert(0, WalletTx(txId: orderId, type: 'consumption', title: '消费 · ${sku.name} · 平债 +${offset.toStringAsFixed(1)} DP', amount: channel == 'wallet' ? -sku.price : 0, createdAt: DateTime.now()));
      db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'DEBT_POINTS.ISSUED · 消费平债 +${offset.toStringAsFixed(1)} DP', body: '购买「${sku.name}」平台利润 ¥${sku.platformMargin} × ${q.finalMultiplier.toStringAsFixed(1)} 倍（${q.explain}），已自动计入债务积分池。', at: DateTime.now()));
      return {'order_id': orderId, 'paid': sku.price, 'platform_margin': sku.platformMargin, 'multiplier': q.finalMultiplier, 'rules': q.appliedRules, 'debt_points_issued': offset, 'dp_batch_id': batch.batchId, 'webhook': 'PAYMENT.SUCCESS'};
    }
    throw ApiException(40401, '资源不存在');
  }

  // ───── 债务积分账户 ─────
  dynamic _debtPoints(String m, List<String> s, Map<String, dynamic> b) {
    final mine = db.debtPoints.where((x) => x.userId == me.userId).toList();
    final face = mine.fold(0.0, (a, x) => a + x.remaining);
    final cash = mine.fold(0.0, (a, x) => a + (x.remaining == 0 ? 0 : x.cashBacked * (x.remaining / x.faceValue)));
    return {'available_points': face, 'cash_backed': cash, 'backing_ratio': face == 0 ? 0 : cash / face, 'batches': mine.length};
  }

  // ───── 银行清缴：积分转交 → 银行核销 → 结清单 ─────
  dynamic _clearance(String m, List<String> s, Map<String, dynamic> b) {
    if (s.length == 3 && s[2] == 'submit' && m == 'POST') {
      final c = db.debtCases.firstWhere((c) => c.caseId == b['case_id'], orElse: () => throw ApiException(40401, '案件不存在'));
      if (c.userId != me.userId) throw ApiException(40303, '非本人案件');
      if (c.status == 3) throw ApiException(40901, '案件已结清');
      if (db.clearances.any((x) => x.caseId == c.caseId && x.status < ClearanceStatus.done)) throw ApiException(40901, '该案件已有清缴单在处理中');
      final avail = availablePoints(me.userId);
      var pts = (b['points'] as num?)?.toDouble() ?? avail;
      if (pts <= 0) throw ApiException(40001, 'points 必须 > 0');
      if (pts > avail) throw ApiException(50301, '债务积分不足：可用 ${avail.toStringAsFixed(1)} DP');
      pts = min(pts, c.outstanding);
      // FIFO 消耗批次，按比例计算现金背书
      double need = pts, cash = 0;
      final consumedMap = <String, double>{};
      for (final batch in db.debtPoints.where((x) => x.userId == me.userId && x.remaining > 0).toList().reversed) {
        if (need <= 0) break;
        final use = min(need, batch.remaining);
        cash += batch.cashBacked * (use / batch.faceValue);
        batch.consumed += use;
        consumedMap[batch.batchId] = use;
        need -= use;
      }
      final reduction = pts - cash;
      final cl = ClearanceOrder(clearanceId: db.nextId('CL'), userId: me.userId, caseId: c.caseId, bankName: c.creditorName, points: pts, cashRemitted: cash, reductionAccepted: reduction, consumedBatches: consumedMap, createdAt: DateTime.now());
      cl.history.add(ClearanceEvent(10, '用户提交 ${pts.toStringAsFixed(1)} DP · 现金背书 ${(cash / pts * 100).toStringAsFixed(0)}%', DateTime.now(), operator: 'USER:${me.userId}'));
      db.clearances.insert(0, cl);
      _postLedger('clearance_remit', cl.clearanceId, [
        ('债务积分现金备付金 · ${me.userId}', 'D', cash, 0),
        ('银行清缴在途 · ${c.creditorName}', 'C', cash, 0),
      ]);
      // 有接入开放平台的银行（存在该行专员账号）走人工受理；其余债权方走自动 Webhook 模拟
      final hasBankOfficer = db.users.values.any((u) => u.role.isBank && u.orgName == c.creditorName);
      if (!hasBankOfficer) _runBankClearance(cl, c);
      db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'CLEARANCE.SUBMITTED · 清缴单已提交', body: '${cl.clearanceId} 已推送至 ${c.creditorName}${hasBankOfficer ? '，等待清收专员受理' : '，银行系统自动处理中'}。', at: DateTime.now()));
      return {'clearance_id': cl.clearanceId, 'points': pts, 'cash_remitted': cash, 'reduction_requested': reduction, 'status': cl.status, 'processing': hasBankOfficer ? 'manual (bank officer)' : 'auto (webhook)', 'webhook': 'CLEARANCE.SUBMITTED'};
    }
    throw ApiException(40401, '资源不存在');
  }

  /// 模拟银行侧异步处理（Webhook 回调）
  void _runBankClearance(ClearanceOrder cl, DebtCase c) {
    final uid = cl.userId;
    Future.delayed(const Duration(milliseconds: 1500), () {
      cl.status = 20;
      cl.history.add(ClearanceEvent(20, '银行受理 · 核验 Consent ${c.consentId} & 积分背书比例', DateTime.now()));
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      cl.status = 30;
      cl.history.add(ClearanceEvent(30, '平台存管账户汇出 ¥${cl.cashRemitted.toStringAsFixed(2)} · 银联代付', DateTime.now()));
    });
    Future.delayed(const Duration(milliseconds: 4500), () {
      cl.status = 40;
      c.outstanding = max(0, c.outstanding - cl.points);
      c.cashPaid += cl.cashRemitted;
      c.pointsCleared += cl.points;
      cl.history.add(ClearanceEvent(40, '银行核销债务 ¥${cl.points.toStringAsFixed(2)}（现金 ¥${cl.cashRemitted.toStringAsFixed(2)} + 协商减免 ¥${cl.reductionAccepted.toStringAsFixed(2)}）', DateTime.now()));
      final u = db.users[uid]!;
      final save = _currentUserId;
      _currentUserId = uid;
      _bumpRedeem(cl.points);
      _currentUserId = save;
      u.creditScore += 3;
    });
    Future.delayed(const Duration(milliseconds: 6000), () {
      cl.status = 50;
      cl.history.add(ClearanceEvent(50, 'Webhook CLEARANCE.COMPLETED', DateTime.now()));
      db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'CLEARANCE.COMPLETED · 银行已核销 ${cl.points.toStringAsFixed(1)} DP', body: '${c.creditorName} 已核销债务 ¥${cl.points.toStringAsFixed(2)}，剩余待还 ¥${c.outstanding.toStringAsFixed(2)}。', at: DateTime.now()));
      if (c.outstanding <= 0.005) _issueCertificate(c, issuedBy: '${c.creditorName} 系统自动');
    });
  }

  // ───── 银行侧 B 端 API（开放平台 Kong-Open · AppKey + 签名） ─────
  dynamic _bank(String m, List<String> s, Map<String, dynamic> b) {
    if (!me.role.isBank) throw ApiException(40303, '权限不足：银行侧 API 仅限债权方机构账号');
    final org = me.orgName!;
    if (s.length == 3 && s[2] == 'clearances') {
      final mine = db.clearances.where((c) => c.bankName == org).toList();
      return {'org': org, 'total': mine.length, 'pending': mine.where((c) => c.status == 10).length};
    }
    if (s.length == 3 && s[2] == 'cases') {
      return {'org': org, 'total': db.debtCases.where((c) => c.creditorName == org).length};
    }
    // 批量核销（事务语义：全部校验通过才执行；幂等级别 L4）
    if (s.length == 4 && s[2] == 'clearances' && s[3] == 'batch-write-off' && m == 'POST') {
      if (!me.can('bank.clearance.batch_write_off')) throw ApiException(40303, '权限不足：bank.clearance.batch_write_off');
      final ids = List<String>.from(b['clearance_ids'] ?? []);
      if (ids.isEmpty) throw ApiException(40001, 'clearance_ids 不能为空');
      if (ids.length > 50) throw ApiException(40001, '单批最多 50 笔');
      final acceptReduction = b['accept_reduction'] != false;
      final targets = <ClearanceOrder>[];
      for (final id in ids) {
        final cl = db.clearances.firstWhere((c) => c.clearanceId == id, orElse: () => throw ApiException(40401, '清缴单 $id 不存在'));
        if (cl.bankName != org) throw ApiException(40303, '$id 不属于本机构，整批回滚');
        if (cl.status != 30) throw ApiException(40901, '$id 状态为「${ClearanceStatus.label(cl.status)}」，需在「资金划付」才可核销，整批回滚');
        targets.add(cl);
      }
      final batchId = db.nextId('BWO');
      double total = 0;
      final results = <Map<String, dynamic>>[];
      for (final cl in targets) {
        final c = db.debtCases.firstWhere((c) => c.caseId == cl.caseId);
        final writeOff = acceptReduction ? cl.points : cl.cashRemitted;
        cl.status = 40;
        c.outstanding = max(0, c.outstanding - writeOff);
        c.cashPaid += cl.cashRemitted;
        c.pointsCleared += writeOff;
        cl.history.add(ClearanceEvent(40, '批量核销 $batchId · ¥${writeOff.toStringAsFixed(2)}', DateTime.now(), operator: 'BANK:${me.nickname}'));
        cl.status = 50;
        cl.history.add(ClearanceEvent(50, 'Webhook CLEARANCE.COMPLETED', DateTime.now()));
        final save = _currentUserId;
        _currentUserId = cl.userId;
        _bumpRedeem(writeOff);
        _currentUserId = save;
        db.users[cl.userId]?.creditScore += 3;
        total += writeOff;
        results.add({'clearance_id': cl.clearanceId, 'written_off': writeOff, 'case_outstanding': c.outstanding});
        db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'CLEARANCE.COMPLETED · $org 已核销 ${writeOff.toStringAsFixed(1)} DP', body: '批量核销 $batchId · 剩余待还 ¥${c.outstanding.toStringAsFixed(2)}', at: DateTime.now()));
      }
      return {'batch_id': batchId, 'count': targets.length, 'total_written_off': total, 'results': results, 'audit_log_id': db.nextId('AUD')};
    }
    // 日终对账文件
    if (s.length == 3 && s[2] == 'recon' && m == 'POST') {
      if (!me.can('bank.recon.generate')) throw ApiException(40303, '权限不足：bank.recon.generate');
      final today = DateTime.now();
      final dateStr = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
      if (db.reconFiles.any((f) => f.bankName == org && f.bizDate.year == today.year && f.bizDate.month == today.month && f.bizDate.day == today.day && f.status == 'confirmed')) {
        throw ApiException(40901, '今日对账文件已确认，不可重复生成');
      }
      db.reconFiles.removeWhere((f) => f.bankName == org && f.status == 'generated');
      // 本行所有已到达「资金划付」及以后的清缴单（排除已对平文件内的）
      final covered = db.reconFiles.where((f) => f.bankName == org && f.status == 'confirmed').expand((f) => f.lines.map((l) => l.clearanceId)).toSet();
      final cls = db.clearances.where((c) => c.bankName == org && c.status >= 30 && c.status != 90 && !covered.contains(c.clearanceId)).toList();
      final lines = <ReconLine>[];
      for (var i = 0; i < cls.length; i++) {
        final cl = cls[i];
        final c = db.debtCases.firstWhere((c) => c.caseId == cl.caseId);
        // 模拟银行侧实收：绝大多数一致；人为制造 1 笔差错演示（金额尾差）
        final received = (i == cls.length - 1 && cls.length >= 2) ? cl.cashRemitted - 0.01 : cl.cashRemitted;
        final written = cl.status >= 40 ? (c.pointsCleared > 0 ? cl.points : 0.0) : 0.0;
        lines.add(ReconLine(clearanceId: cl.clearanceId, userId: cl.userId, caseNo: c.caseNo, platformRemitted: cl.cashRemitted, bankReceived: received, writtenOff: written, status: cl.status < 40 ? 'pending' : ((cl.cashRemitted - received).abs() > 0.001 ? 'diff' : 'matched'), bankRef: 'UNP$dateStr${(i + 1).toString().padLeft(3, '0')}'));
      }
      final file = ReconFile(fileId: db.nextId('RF'), fileName: 'XG_${org.substring(0, 2) == '招商' ? 'CMB' : 'BANK'}_RECON_$dateStr.csv', bankName: org, bizDate: today, lines: lines, generatedAt: DateTime.now(), checksum: 'sha256:${_rand.nextInt(1 << 30).toRadixString(16).padLeft(8, '0')}…${_rand.nextInt(1 << 20).toRadixString(16)}');
      db.reconFiles.insert(0, file);
      return {'file_id': file.fileId, 'file_name': file.fileName, 'lines': lines.length, 'matched': lines.where((l) => l.status == 'matched').length, 'diff': file.diffCount, 'pending': lines.where((l) => l.status == 'pending').length, 'total_remitted': file.totalRemitted, 'total_received': file.totalReceived, 'checksum': file.checksum};
    }
    if (s.length == 5 && s[2] == 'recon' && s[4] == 'confirm') {
      if (!me.can('bank.recon.confirm')) throw ApiException(40303, '权限不足：bank.recon.confirm');
      final f = db.reconFiles.firstWhere((f) => f.fileId == s[3], orElse: () => throw ApiException(40401, '对账文件不存在'));
      if (f.bankName != org) throw ApiException(40303, '非本机构文件');
      if (f.status == 'confirmed') throw ApiException(40901, '已确认');
      if (f.diffCount > 0 && b['force'] != true) throw ApiException(40901, '存在 ${f.diffCount} 笔差错，需处理或 force=true 带差错对平（进入差错处理队列）');
      f.status = 'confirmed';
      f.confirmedBy = me.nickname;
      return {'file_id': f.fileId, 'status': 'confirmed', 'diff_queue': f.diffCount, 'settlement_summary': {'remitted': f.totalRemitted, 'received': f.totalReceived, 'written_off': f.totalWrittenOff}, 'webhook': 'RECON.CONFIRMED'};
    }
    if (s.length == 5 && s[2] == 'clearances') {
      final cl = db.clearances.firstWhere((c) => c.clearanceId == s[3], orElse: () => throw ApiException(40401, '清缴单不存在'));
      // ABAC：租户隔离
      if (cl.bankName != org) throw ApiException(40303, '业务实体归属校验失败：该清缴单属于 ${cl.bankName}');
      final c = db.debtCases.firstWhere((c) => c.caseId == cl.caseId);
      final op = 'BANK:${me.nickname}';
      switch (s[4]) {
        case 'accept':
          if (cl.status != 10) throw ApiException(40901, '状态非法：${ClearanceStatus.label(cl.status)} 不可受理');
          cl.status = 20;
          cl.bankOperator = me.nickname;
          cl.history.add(ClearanceEvent(20, '受理 · ${b['note'] ?? '核验 Consent ${c.consentId} / 积分背书 ${(cl.cashRemitted / cl.points * 100).toStringAsFixed(0)}%'}', DateTime.now(), operator: op));
          return {'clearance_id': cl.clearanceId, 'status': cl.status, 'webhook': 'CLEARANCE.ACCEPTED'};
        case 'confirm-remit':
          if (cl.status != 20) throw ApiException(40901, '状态非法：需先受理');
          cl.status = 30;
          cl.history.add(ClearanceEvent(30, '确认收到平台存管汇款 ¥${cl.cashRemitted.toStringAsFixed(2)} · 银联流水 ${b['bank_ref'] ?? db.nextId('UNP')}', DateTime.now(), operator: op));
          _postLedger('clearance_settle', cl.clearanceId, [
            ('银行清缴在途 · $org', 'D', cl.cashRemitted, 0),
            ('债权方实收 · $org', 'C', cl.cashRemitted, 0),
          ]);
          return {'clearance_id': cl.clearanceId, 'status': cl.status, 'cash_confirmed': cl.cashRemitted};
        case 'write-off':
          if (cl.status != 30) throw ApiException(40901, '状态非法：需先确认资金到账');
          final acceptReduction = b['accept_reduction'] != false;
          final writeOff = acceptReduction ? cl.points : cl.cashRemitted;
          cl.status = 40;
          c.outstanding = max(0, c.outstanding - writeOff);
          c.cashPaid += cl.cashRemitted;
          c.pointsCleared += writeOff;
          cl.history.add(ClearanceEvent(40, '核销债务 ¥${writeOff.toStringAsFixed(2)}（现金 ¥${cl.cashRemitted.toStringAsFixed(2)} + 减免 ¥${(writeOff - cl.cashRemitted).toStringAsFixed(2)}）${acceptReduction ? '' : ' · 未接受协商减免'}', DateTime.now(), operator: op));
          final u = db.users[cl.userId]!;
          final save = _currentUserId;
          _currentUserId = cl.userId;
          _bumpRedeem(writeOff);
          _currentUserId = save;
          u.creditScore += 3;
          // 完成
          cl.status = 50;
          cl.history.add(ClearanceEvent(50, 'Webhook CLEARANCE.COMPLETED → 平台', DateTime.now()));
          db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'CLEARANCE.COMPLETED · $org 已核销 ${writeOff.toStringAsFixed(1)} DP', body: '清收专员 ${me.nickname} 已核销债务 ¥${writeOff.toStringAsFixed(2)}，剩余待还 ¥${c.outstanding.toStringAsFixed(2)}。', at: DateTime.now()));
          final cleared = c.outstanding <= 0.005;
          return {'clearance_id': cl.clearanceId, 'status': cl.status, 'written_off': writeOff, 'case_outstanding': c.outstanding, 'case_cleared': cleared, 'next': cleared ? 'issue certificate' : null};
        case 'reject':
          if (cl.status >= 40) throw ApiException(40901, '已核销不可退回');
          final reason = b['reason'] as String? ?? '资料不全';
          cl.status = 90;
          cl.rejectReason = reason;
          cl.history.add(ClearanceEvent(90, '退回 · $reason', DateTime.now(), operator: op));
          // 积分回滚（按批次精确还原）+ 备付金红字冲正
          if (cl.consumedBatches.isNotEmpty) {
            for (final e in cl.consumedBatches.entries) {
              final batch = db.debtPoints.where((x) => x.batchId == e.key).firstOrNull;
              if (batch != null) batch.consumed = max(0, batch.consumed - e.value);
            }
          } else {
            // 种子数据无批次映射：按 FIFO 还原
            double back = cl.points;
            for (final batch in db.debtPoints.where((x) => x.userId == cl.userId && x.consumed > 0)) {
              if (back <= 0) break;
              final r = min(back, batch.consumed);
              batch.consumed -= r;
              back -= r;
            }
          }
          _postLedger('clearance_reverse', cl.clearanceId, [
            ('银行清缴在途 · $org', 'D', cl.cashRemitted, 0),
            ('债务积分现金备付金 · ${cl.userId}', 'C', cl.cashRemitted, 0),
          ]);
          db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'CLEARANCE.REJECTED · 清缴单被退回', body: '$org 退回 ${cl.clearanceId}：$reason。积分已返还至你的积分池。', at: DateTime.now()));
          return {'clearance_id': cl.clearanceId, 'status': 90, 'points_returned': cl.points};
        case 'issue-certificate':
          if (c.outstanding > 0.005) throw ApiException(40901, '案件余额未归零（¥${c.outstanding.toStringAsFixed(2)}），不可签发结清证明');
          if (c.certificateId != null) throw ApiException(40901, '已签发过结清证明');
          _issueCertificate(c, issuedBy: me.nickname);
          final cert = db.certificates.firstWhere((x) => x.caseId == c.caseId);
          return {'certificate_id': cert.certId, 'cert_no': cert.certNo, 'webhook': 'CERTIFICATE.ISSUED'};
      }
    }
    throw ApiException(40401, '资源不存在');
  }

  void _issueCertificate(DebtCase c, {String issuedBy = 'SYSTEM'}) {
    c.status = 3;
    c.negotiationStatus = 4;
    final plan = db.plans.where((p) => p.planId == c.planId).firstOrNull;
    if (plan != null && plan.status == 3) plan.status = 4;
    final cert = ClearanceCertificate(
      certId: db.nextId('CERT'),
      certNo: 'XG-${c.creditorName.hashCode.abs() % 900 + 100}-${DateTime.now().year}-${db.nextId('').padLeft(6, '0')}',
      caseId: c.caseId,
      userId: c.userId,
      bankName: c.creditorName,
      caseNo: c.caseNo,
      originalDebt: c.originalDebt,
      totalCleared: c.originalDebt,
      cashPaid: c.cashPaid + (plan?.paidAmount ?? 0),
      pointsReduction: c.originalDebt - c.cashPaid - (plan?.paidAmount ?? 0),
      issuedAt: DateTime.now(),
      signature: 'SM2:${_rand.nextInt(1 << 30).toRadixString(16).padLeft(8, '0')}…${_rand.nextInt(1 << 30).toRadixString(16)}',
      issuedBy: issuedBy,
    );
    db.certificates.insert(0, cert);
    c.certificateId = cert.certId;
    db.notifications.insert(0, AppNotification(id: db.nextId('N'), category: 'finance', title: 'CERTIFICATE.ISSUED · 《债务结清证明》已出具', body: '${c.creditorName} 已对案件 ${c.caseNo} 出具结清证明 ${cert.certNo}。正式上岸！✨', at: DateTime.now()));
  }

  // ───── 通知 ─────
  dynamic _notifications(String m, List<String> s, Map<String, dynamic> b) {
    if (s.length == 3 && s[2] == 'read-all') {
      for (final n in db.notifications) {
        n.read = true;
      }
      return {'read': db.notifications.length};
    }
    return {'unread': db.notifications.where((n) => !n.read).length};
  }

  // ───── 管理域 M01 / M02 ─────
  dynamic _admin(String m, List<String> s, Map<String, dynamic> b) {
    if (!me.role.isAdmin) throw ApiException(40303, '权限不足：B 端 API 需管理角色 + IP 白名单 + 2FA');
    final sub = s.sublist(2).join('/');
    if (sub.startsWith('risk/cases/') && s.length >= 5) {
      final rc = db.riskCases.firstWhere((r) => r.caseId == s[4], orElse: () => throw ApiException(40401, '案件不存在'));
      final action = b['action'] as String? ?? 'log';
      rc.status = 'resolved';
      rc.disposition = action;
      final target = db.users[rc.userId];
      switch (action) {
        case 'freeze':
          if (target != null) target.status = UserStatus.frozen;
          break;
        case 'ban':
          if (target != null) target.status = UserStatus.banned;
          break;
        case 'unfreeze':
          if (target != null) target.status = UserStatus.normal;
          break;
        case 'downgrade':
          if (target != null) target.riskLevel = max(0, target.riskLevel - 1);
          break;
      }
      return {'case_id': rc.caseId, 'disposition': action, 'audit_log_id': db.nextId('AUD'), 'worm_storage': true};
    }
    if (sub.startsWith('risk/rules/') && s.length >= 5) {
      final r = db.riskRules.firstWhere((r) => r.ruleCode == s[4], orElse: () => throw ApiException(40401, '规则不存在'));
      final st = (b['status'] as num?)?.toInt();
      if (st == 2 && !me.can('risk.rule.create')) throw ApiException(40303, '发布规则需 risk.rule.publish 审批流');
      if (st != null) r.status = st;
      return {'rule_code': r.ruleCode, 'status': r.status};
    }
    if (sub.startsWith('moderation/') && s.length >= 4) {
      final c = db.contents.firstWhere((c) => c.contentId == s[3], orElse: () => throw ApiException(40401, '内容不存在'));
      final approve = b['approve'] == true;
      if (approve) {
        c.moderationStatus = 2;
        c.status = 1;
      } else {
        c.moderationStatus = 3;
        c.status = 2;
        c.moderationReason = b['reason'] ?? '人工复审拒绝';
      }
      return {'content_id': c.contentId, 'moderation_status': c.moderationStatus, 'webhook': approve ? null : 'CONTENT.MODERATION.REJECTED'};
    }
    // 平债倍率规则（运营）
    if (sub == 'offset-rules' && m == 'POST') {
      if (!me.can('ops.offset_rule.write')) throw ApiException(40303, '权限不足：ops.offset_rule.write');
      final type = b['rule_type'] as String? ?? 'category';
      final v = (b['value'] as num?)?.toDouble();
      if (v == null || v < 0 || v > 10) throw ApiException(40001, 'value 需 0~10');
      final r = OffsetRule(ruleId: db.nextId('OR-'), ruleType: type, name: b['name'] ?? '新规则', category: b['category'], creditMin: (b['credit_min'] as num?)?.toInt(), creditMax: (b['credit_max'] as num?)?.toInt(), value: v, status: 0, createdBy: me.userId);
      db.offsetRules.insert(0, r);
      return {'rule_id': r.ruleId, 'status': 0};
    }
    if (sub.startsWith('offset-rules/') && s.length >= 4) {
      final r = db.offsetRules.firstWhere((r) => r.ruleId == s[3], orElse: () => throw ApiException(40401, '规则不存在'));
      final st = (b['status'] as num?)?.toInt();
      final v = (b['value'] as num?)?.toDouble();
      if (v != null) {
        if (v < 0 || v > 10) throw ApiException(40001, 'value 需 0~10');
        if (r.ruleType == 'global_cap' && v < 1) throw ApiException(50601, '合规校验：全局上限不得低于 1');
        r.value = v;
        if (r.status == 2) r.status = 1; // 生产规则改值自动降为灰度，需重新审批
      }
      if (st != null) {
        if (st == 2) {
          if (!me.can('ops.offset_rule.publish')) throw ApiException(40303, '发布需 ops.offset_rule.publish 审批流');
          r.approvedBy = me.nickname;
        }
        r.status = st;
      }
      return {'rule_id': r.ruleId, 'status': r.status, 'value': r.value, 'audit_log_id': db.nextId('AUD')};
    }
    if (sub == 'dashboard') {
      final totalRepaid = db.users.values.fold<double>(0, (a, u) => a + u.carbonDebtSaved);
      return {
        'north_star': {'monthly_redeem_amount': totalRepaid, 'monthly_redeem_users': 2},
        'dau': 18420 + _rand.nextInt(500),
        'gmv': 1284000,
        'ai_calls': 96420 + _rand.nextInt(1000),
      };
    }
    if (sub == 'tasks/audit' && s.length >= 5) {
      final t = db.tasks.firstWhere((t) => t.taskId == s[4], orElse: () => throw ApiException(40401, '任务不存在'));
      t.status = b['approve'] == true ? 2 : 6;
      return {'task_id': t.taskId, 'status': t.status};
    }
    throw ApiException(40401, '资源不存在');
  }
}
