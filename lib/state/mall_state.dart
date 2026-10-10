import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 后端地址：
/// - Web 由 server 同源托管时自动使用当前域名；
/// - 本地调试 / 移动端通过 `--dart-define=API_BASE=http://<host>:8080` 指定。
String get mallApiBase {
  const env = String.fromEnvironment('API_BASE');
  if (env.isNotEmpty) return env.endsWith('/') ? env.substring(0, env.length - 1) : env;
  if (kIsWeb) return Uri.base.origin;
  return 'http://10.0.2.2:8080'; // Android 模拟器访问宿主机
}

/// 图片等相对路径补全为绝对 URL
String? mallAsset(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return '$mallApiBase$path';
}

class MallException implements Exception {
  final int code;
  final String message;
  MallException(this.code, this.message);
  @override
  String toString() => message;
}

double toD(dynamic v) => v == null ? 0 : (v as num).toDouble();
int toI(dynamic v) => v == null ? 0 : (v as num).toInt();

const orderStatusLabels = {10: '待支付', 20: '待发货', 30: '待收货', 40: '已完成', 50: '已取消', 60: '退款中', 70: '已退款'};
const commissionStatusLabels = {0: '待收货', 1: '保障期中', 2: '已到账', 9: '已失效'};
const clearanceStatusLabels = {10: '已提交', 20: '银行已受理', 30: '资金已划转', 50: '已核减', 90: '已退回'};

/// 指引视频
class Guide {
  final String key;
  final int step;
  final String title;
  final String subtitle;
  final String narration;
  final String video;
  final String poster;
  final String group;
  const Guide({required this.key, required this.step, required this.title, required this.subtitle, required this.narration, required this.video, required this.poster, this.group = 'clear'});
  factory Guide.fromJson(Map<String, dynamic> j) => Guide(key: j['key'], step: toI(j['step']), title: j['title'], subtitle: j['subtitle'], narration: j['narration'], video: j['video'], poster: j['poster'], group: (j['group'] ?? 'clear') as String);
  String get badge => step == 0 ? '平台介绍' : (group == 'labor' ? '微劳动 $step' : '第 $step 步');
}

/// 电商 + 佣金 + 债务清算：真实后端（server/）的客户端状态
class MallState extends ChangeNotifier {
  String? _extId;
  String? _token;
  bool connecting = false;
  String? connectError;

  Map<String, dynamic>? me;
  Map<String, dynamic>? overview;
  Map<String, dynamic>? laborSummary;
  List<dynamic> categories = [];
  List<Guide> guides = [];
  Map<String, dynamic>? stats;
  final Set<String> watchedGuides = {};

  Guide? guide(String key) => guides.where((g) => g.key == key).firstOrNull;
  int cartCount = 0;
  final Map<int, Map<String, dynamic>> quotes = {};

  bool get ready => _token != null;
  bool booted = false;
  bool get loggedIn => _extId != null;
  String? get extId => _extId;
  /// user / merchant / bank / risk / ops
  String get role => (me?['role'] as String?) ?? 'user';
  int tab = 0;
  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  /// 启动：恢复上次登录身份；支持演示深链 ?as=U1001
  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();
    final watched = prefs.getStringList('watched_guides') ?? [];
    watchedGuides.addAll(watched);
    final deep = Uri.base.queryParameters['as'];
    final ext = (deep != null && deep.isNotEmpty) ? deep : prefs.getString('ext_id');
    booted = true;
    if (ext != null) {
      bindUser(ext);
      unawaited(connect());
    } else {
      notifyListeners();
    }
  }

  Future<void> loginAs(String ext) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ext_id', ext);
    tab = 0;
    bindUser(ext);
    await connect();
    if (connectError != null) throw MallException(-1, connectError!);
  }

  /// 手机号 + 验证码登录（新手机号自动注册）
  Future<void> loginSms(String mobile, String code) async {
    final r = await _req('POST', '/app/auth/sms-login', body: {'mobile': mobile, 'code': code}, auth: false);
    final u = Map<String, dynamic>.from(r['user']);
    final ext = (u['ext_id'] as String?) ?? 'M:$mobile';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ext_id', ext);
    _extId = ext;
    _token = r['token'] as String;
    tab = 0;
    await Future.wait([refreshMe(), loadCategories(), refreshCart(), _loadPublic()]);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ext_id');
    bindUser(null);
    notifyListeners();
  }
  Map<String, dynamic> get dp => (me?['debt_points'] as Map<String, dynamic>?) ?? const {};

  /// App 身份切换时调用：用演示身份 ext_id（U1001…）换取后端令牌
  void bindUser(String? extId) {
    if (extId == _extId && (extId == null || _token != null || connecting)) return;
    _extId = extId;
    _token = null;
    me = null;
    cartCount = 0;
    quotes.clear();
    notifyListeners();
  }

  Future<void> connect() async {
    final ext = _extId;
    if (ext == null) return;
    if (ext.startsWith('M:')) {
      // 手机号登录的会话：令牌失效后需重新登录
      await logout();
      return;
    }
    connecting = true;
    connectError = null;
    notifyListeners();
    try {
      final r = await _req('POST', '/app/auth/demo-login', body: {'ext_id': ext}, auth: false);
      if (ext != _extId) return;
      _token = r['token'] as String;
      await Future.wait([refreshMe(), loadCategories(), refreshCart(), _loadPublic()]);
    } catch (e) {
      connectError = e is MallException ? e.message : '无法连接商城服务（$mallApiBase）';
    } finally {
      connecting = false;
      notifyListeners();
    }
  }

  Future<dynamic> _req(String method, String path, {Object? body, bool auth = true}) async {
    final uri = Uri.parse('$mallApiBase/api$path');
    final headers = {'content-type': 'application/json', if (auth && _token != null) 'authorization': 'Bearer $_token'};
    final payload = body == null ? null : jsonEncode(body);
    late http.Response res;
    try {
      res = switch (method) {
        'GET' => await http.get(uri, headers: headers),
        'POST' => await http.post(uri, headers: headers, body: payload ?? '{}'),
        'PATCH' => await http.patch(uri, headers: headers, body: payload ?? '{}'),
        'DELETE' => await http.delete(uri, headers: headers),
        _ => throw ArgumentError(method),
      };
    } catch (_) {
      throw MallException(-1, '网络异常，请检查商城服务是否启动');
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw MallException(res.statusCode, '服务返回异常 (${res.statusCode})');
    }
    final code = toI(j['code']);
    if (code == 40101 && auth) {
      _token = null;
      Future.microtask(connect);
    }
    if (code != 0) throw MallException(code, (j['message'] ?? '请求失败').toString());
    return j['data'];
  }

  Future<dynamic> get(String p) => _req('GET', '/app$p');
  Future<dynamic> post(String p, [Object? b]) => _req('POST', '/app$p', body: b ?? const {});
  Future<dynamic> del(String p) => _req('DELETE', '/app$p');

  /// 上传图片（交付物 / 社区配图），返回 URL
  Future<String> upload(List<int> bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$mallApiBase/api/app/upload'))
      ..headers['authorization'] = 'Bearer $_token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final res = await http.Response.fromStream(await req.send());
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (toI(j['code']) != 0) throw MallException(toI(j['code']), (j['message'] ?? '上传失败').toString());
    return (j['data'] as Map)['url'] as String;
  }

  // ───── 账户 ─────
  Future<void> refreshMe() async {
    final r = await Future.wait([get('/me'), get('/overview')]);
    me = Map<String, dynamic>.from(r[0]);
    overview = Map<String, dynamic>.from(r[1]);
    if (role == 'user') laborSummary = Map<String, dynamic>.from(await get('/labor/summary'));
    notifyListeners();
  }

  Future<void> _loadPublic() async {
    if (guides.isEmpty) guides = (await get('/guides') as List).map((e) => Guide.fromJson(Map<String, dynamic>.from(e))).toList();
    stats ??= Map<String, dynamic>.from(await get('/stats'));
  }

  void markWatched(String key) {
    if (watchedGuides.add(key)) {
      notifyListeners();
      SharedPreferences.getInstance().then((p) => p.setStringList('watched_guides', watchedGuides.toList()));
    }
  }

  List<Guide> guidesOf(String group) => guides.where((g) => g.group == group || (group == 'clear' && g.step == 0)).toList();

  // ───── 银行 ─────
  Future<Map<String, dynamic>> bankSms(String mobile) async => Map<String, dynamic>.from(await post('/bank/sms', {'mobile': mobile}));
  Future<Map<String, dynamic>> bankQuery(String mobile, String code) async => Map<String, dynamic>.from(await post('/bank/query', {'mobile': mobile, 'code': code, 'consent': true}));
  Future<Map<String, dynamic>> bankImport(List<int> ids) async {
    final r = Map<String, dynamic>.from(await post('/bank/import', {'account_ids': ids}));
    await refreshMe();
    return r;
  }

  Future<List<dynamic>> letters() async => await get('/bank/letters') as List<dynamic>;
  Future<void> readLetter(int id) async {
    await post('/bank/letters/$id/read');
    await refreshMe();
  }

  Future<List<dynamic>> certificates() async => await get('/certificates') as List<dynamic>;
  Future<List<dynamic>> notifications() async => await get('/notifications') as List<dynamic>;

  Future<void> loadCategories() async {
    categories = await get('/categories') as List<dynamic>;
    notifyListeners();
  }

  // ───── 商品 ─────
  Future<List<dynamic>> products({int? categoryId, String? keyword, String? sort, int size = 100}) async {
    final q = <String, String>{'size': '$size', if (categoryId != null) 'category_id': '$categoryId', if (keyword != null && keyword.isNotEmpty) 'keyword': keyword, if (sort != null) 'sort': sort};
    final r = await get('/products?${Uri(queryParameters: q).query}');
    final list = (r['list'] as List<dynamic>);
    await _loadQuotes(list.map((p) => toI(p['id'])).toList());
    return list;
  }

  Future<Map<String, dynamic>> product(int id) async {
    final p = Map<String, dynamic>.from(await get('/products/$id'));
    await _loadQuotes([id]);
    return p;
  }

  Future<void> _loadQuotes(List<int> ids) async {
    if (ids.isEmpty || !ready) return;
    final r = await post('/quote', {'product_ids': ids}) as Map<String, dynamic>;
    r.forEach((k, v) => quotes[int.parse(k)] = Map<String, dynamic>.from(v));
    notifyListeners();
  }

  // ───── 购物车 ─────
  Future<List<dynamic>> cart() async {
    final l = await get('/cart') as List<dynamic>;
    cartCount = l.fold(0, (a, x) => a + toI(x['qty']));
    notifyListeners();
    return l;
  }

  Future<void> refreshCart() async => cart();

  Future<void> addToCart(int productId, int qty) async {
    final l = await post('/cart', {'product_id': productId, 'qty': qty}) as List<dynamic>;
    cartCount = l.fold(0, (a, x) => a + toI(x['qty']));
    notifyListeners();
  }

  Future<void> updateCart(int cartItemId, {int? qty, bool? checked}) async {
    await _req('PATCH', '/app/cart/$cartItemId', body: {'qty': ?qty, 'checked': ?checked});
    await refreshCart();
  }

  Future<void> removeCart(int cartItemId) async {
    await _req('DELETE', '/app/cart/$cartItemId');
    await refreshCart();
  }

  // ───── 地址 ─────
  Future<List<dynamic>> addresses() async => await get('/addresses') as List<dynamic>;
  Future<Map<String, dynamic>> addAddress(Map<String, dynamic> a) async => Map<String, dynamic>.from(await post('/addresses', a));

  // ───── 订单 ─────
  Future<Map<String, dynamic>> preview(List<Map<String, dynamic>> items) async => Map<String, dynamic>.from(await post('/orders/preview', {'items': items}));

  Future<Map<String, dynamic>> createOrder(List<Map<String, dynamic>> items, {int? addressId, String? remark, bool fromCart = false}) async {
    final o = Map<String, dynamic>.from(await post('/orders', {'items': items, 'address_id': addressId, 'remark': remark, 'from_cart': fromCart}));
    if (fromCart) await refreshCart();
    return o;
  }

  Future<List<dynamic>> orders({int? status}) async => await get('/orders${status == null ? '' : '?status=$status'}') as List<dynamic>;
  Future<Map<String, dynamic>> order(int id) async => Map<String, dynamic>.from(await get('/orders/$id'));

  /// 返回 {paid, pay_no, ...}
  Future<Map<String, dynamic>> pay(int orderId, String channel) async {
    final r = Map<String, dynamic>.from(await post('/orders/$orderId/pay', {'channel': channel}));
    if (r['paid'] == true) await refreshMe();
    return r;
  }

  /// 模拟第三方收银台完成支付（演示环境）
  Future<void> mockConfirmPay(String payNo) async {
    await _req('POST', '/pay/mock/$payNo/confirm', auth: false);
    await refreshMe();
  }

  Future<void> orderAction(int id, String action, [Map<String, dynamic>? body]) async {
    await post('/orders/$id/$action', body);
    await refreshMe();
  }

  Future<void> recharge(double amount) async {
    await post('/wallet/recharge', {'amount': amount});
    await refreshMe();
  }

  // ───── 佣金 / 积分 / 清算 ─────
  Future<Map<String, dynamic>> commissions() async => Map<String, dynamic>.from(await get('/commissions'));
  Future<Map<String, dynamic>> debtPoints() async => Map<String, dynamic>.from(await get('/debt-points'));
  Future<List<dynamic>> debts() async => await get('/debts') as List<dynamic>;
  Future<List<dynamic>> clearances() async => await get('/clearances') as List<dynamic>;

  Future<Map<String, dynamic>> submitClearance(int caseId, double? points) async {
    final r = Map<String, dynamic>.from(await post('/clearances', {'case_id': caseId, 'points': ?points}));
    await refreshMe();
    return r;
  }

  Future<Map<String, dynamic>> addDebt(Map<String, dynamic> d) async => Map<String, dynamic>.from(await post('/debts', d));
}
