import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_gateway.dart';
import '../services/mock_db.dart';

/// 全局应用状态：会话（多用户切换）+ 数据视图 + API 调用封装
class AppState extends ChangeNotifier {
  final ApiGateway api = ApiGateway.instance;
  final MockDb db = MockDb.instance;

  String? _userId;
  bool _booted = false;
  int tabIndex = 0;

  bool get booted => _booted;
  bool get loggedIn => _userId != null;
  UserProfile get me => db.users[_userId]!;
  UserProfile? get meOrNull => _userId == null ? null : db.users[_userId];
  List<UserProfile> get allUsers => db.users.values.toList();

  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    // 深链演示：?as=U1001 直接进入指定身份（模拟设备指纹免密登录）
    final deepLink = Uri.base.queryParameters['as'];
    final saved = deepLink ?? prefs.getString('session_user');
    if (saved != null && db.users.containsKey(saved)) {
      _userId = saved;
      api.setSession(saved);
    }
    _booted = true;
    notifyListeners();
  }

  /// 登录（短信验证码）—— API-A-003
  Future<ApiResponse> login(String userId, String smsCode) async {
    final r = await api.call('POST', '/v1/auth/login/sms', apiId: 'API-A-003', body: {'user_id': userId, 'sms_code': smsCode});
    if (r.ok) {
      _userId = userId;
      tabIndex = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_user', userId);
    }
    notifyListeners();
    return r;
  }

  /// 多用户快速切换（模拟已绑定设备的免密切换）
  Future<void> switchUser(String userId) async {
    await api.call('POST', '/v1/auth/logout', apiId: 'API-A-008');
    api.setSession(userId);
    _userId = userId;
    tabIndex = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user', userId);
    notifyListeners();
  }

  Future<void> logout() async {
    await api.call('POST', '/v1/auth/logout', apiId: 'API-A-008');
    _userId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user');
    notifyListeners();
  }

  void setTab(int i) {
    tabIndex = i;
    notifyListeners();
  }

  /// 统一 API 调用封装：调用后刷新 UI
  Future<ApiResponse> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? apiId,
    String? requestId,
    int? kycRequired,
    String? permission,
    bool requirePayToken = false,
  }) async {
    final r = await api.call(method, path, body: body, apiId: apiId, requestId: requestId, kycRequired: kycRequired, permission: permission, requirePayToken: requirePayToken);
    notifyListeners();
    return r;
  }

  void refresh() => notifyListeners();

  // ───── 视图数据 ─────
  DebtProfile? get myDebtProfile => db.debtProfiles[_userId];
  List<DebtCase> get myCases => db.debtCases.where((c) => c.userId == _userId).toList();
  List<RepaymentPlan> plansFor(String caseId) => db.plans.where((p) => p.caseId == caseId).toList();
  List<RepaymentPlan> get myActivePlans => db.plans.where((p) => p.status == 3 && myCases.any((c) => c.caseId == p.caseId)).toList();
  List<Task> get marketTasks => db.tasks.where((t) => t.status == 2 || t.status == 3).toList();
  List<Task> get myPublishedTasks => db.tasks.where((t) => t.publisherId == _userId).toList();
  List<TaskOrder> get myOrders => db.orders.where((o) => o.userId == _userId).toList();
  List<TaskOrder> ordersForTask(String taskId) => db.orders.where((o) => o.taskId == taskId).toList();
  Task taskOf(String id) => db.tasks.firstWhere((t) => t.taskId == id);
  List<Content> get feed => db.contents.where((c) => c.status == 1).toList();
  List<Content> get myContents => db.contents.where((c) => c.authorId == _userId).toList();
  List<Content> get moderationQueue => db.contents.where((c) => c.moderationStatus == 0 || c.moderationStatus == 4).toList();
  List<WalletTx> get walletTxs => db.walletTxs;
  List<LedgerEntry> get ledger => db.ledger;
  List<Settlement> get mySettlements => db.settlements.where((s) => s.userId == _userId).toList();
  List<AppNotification> get notifications => db.notifications;
  int get unread => db.notifications.where((n) => !n.read).length;
  List<RiskCase> get riskCases => db.riskCases;
  List<RiskRule> get riskRules => db.riskRules;
  List<ApiLog> get apiLogs => db.apiLogs;
}
