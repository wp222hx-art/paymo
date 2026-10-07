import 'package:flutter_test/flutter_test.dart';
import 'package:xinguang_cloud/services/api_gateway.dart';
import 'package:xinguang_cloud/services/mock_db.dart';

void main() {
  test('offset rule engine: category base + credit bonus, capped; ops edit downgrades to gray', () async {
    final api = ApiGateway.instance;
    final db = MockDb.instance;
    // 林晓明 credit 612 → 本地生活 5 + 0.5 = 5.5 → 电影票 5×5.5 = 27.5
    api.setSession('U1001');
    final q = await api.call('POST', '/v1/shop/quote', body: {'sku_id': 'SKU-MOVIE'}, latencyMs: 1);
    expect(q.data['multiplier'], 5.5);
    expect(q.data['offset_points'], 27.5);
    // 苏雨桐 credit 688 → 教育 3 + 1.0 = 4 → 课程 60×4 = 240
    api.setSession('U1002');
    final q2 = await api.call('POST', '/v1/shop/quote', body: {'sku_id': 'SKU-COURSE'}, latencyMs: 1);
    expect(q2.data['multiplier'], 4.0);
    // 运营：把本地生活调到 6 → 生产降灰度；林晓明 6+0.5=6.5 触及上限 6
    api.setSession('U1005');
    final e = await api.call('PUT', '/v1/admin/offset-rules/OR-CAT-001', body: {'value': 6}, latencyMs: 1);
    expect(e.code, 0);
    expect(e.data['status'], 1);
    api.setSession('U1001');
    final q3 = await api.call('POST', '/v1/shop/quote', body: {'sku_id': 'SKU-MOVIE'}, latencyMs: 1);
    expect(q3.data['multiplier'], 6.0);
    expect((q3.data['rules'] as List).contains('OR-CAP-001'), true);
    // 下单落快照
    final o = await api.call('POST', '/v1/shop/orders', body: {'sku_id': 'SKU-MOVIE', 'channel': 'wechat'}, latencyMs: 1);
    expect(o.data['debt_points_issued'], 30.0);
    expect(db.debtPoints.first.ruleSnapshot, isNotNull);
    // 非运营无权
    final x = await api.call('PUT', '/v1/admin/offset-rules/OR-CAT-001', body: {'status': 2}, latencyMs: 1);
    expect(x.code, 40303);
    // 风控专员是 admin 但无 publish 权限
    api.setSession('U1004');
    final y = await api.call('PUT', '/v1/admin/offset-rules/OR-CAT-001', body: {'status': 2}, latencyMs: 1);
    expect(y.code, 40303);
    api.setSession('U1005');
    expect((await api.call('PUT', '/v1/admin/offset-rules/OR-CAT-001', body: {'status': 2}, latencyMs: 1)).data['status'], 2);
  });

  test('bank batch write-off (atomic) + daily recon file', () async {
    final api = ApiGateway.instance;
    final db = MockDb.instance;
    api.setSession('U1006');
    // CL8003 在 20 → 推到 30；CL8002 在 10 → 混入批量应整批回滚
    expect((await api.call('POST', '/v1/bank/clearances/CL8003/confirm-remit', latencyMs: 1)).code, 0);
    final bad = await api.call('POST', '/v1/bank/clearances/batch-write-off', body: {'clearance_ids': ['CL8003', 'CL8002']}, latencyMs: 1);
    expect(bad.code, 40901);
    expect(db.clearances.firstWhere((c) => c.clearanceId == 'CL8003').status, 30, reason: 'atomic rollback: untouched');
    // 把 CL8002 也推到 30 再批量
    expect((await api.call('POST', '/v1/bank/clearances/CL8002/accept', latencyMs: 1)).code, 0);
    expect((await api.call('POST', '/v1/bank/clearances/CL8002/confirm-remit', latencyMs: 1)).code, 0);
    final ok = await api.call('POST', '/v1/bank/clearances/batch-write-off', body: {'clearance_ids': ['CL8003', 'CL8002'], 'accept_reduction': true}, latencyMs: 1);
    expect(ok.code, 0);
    expect(ok.data['count'], 2);
    expect(ok.data['total_written_off'], closeTo(517.4, 0.01));
    expect(db.clearances.where((c) => ['CL8002', 'CL8003'].contains(c.clearanceId)).every((c) => c.status == 50), true);
    // 对账
    final r = await api.call('POST', '/v1/bank/recon', latencyMs: 1);
    expect(r.code, 0);
    expect(r.data['lines'], greaterThanOrEqualTo(2));
    final fileId = r.data['file_id'] as String;
    final f = db.reconFiles.firstWhere((f) => f.fileId == fileId);
    expect(f.diffCount, 1); // 演示差错
    final c1 = await api.call('POST', '/v1/bank/recon/$fileId/confirm', body: {'force': false}, latencyMs: 1);
    expect(c1.code, 40901);
    final c2 = await api.call('POST', '/v1/bank/recon/$fileId/confirm', body: {'force': true}, latencyMs: 1);
    expect(c2.code, 0);
    expect(f.status, 'confirmed');
    // 重复生成当日 → 冲突
    expect((await api.call('POST', '/v1/bank/recon', latencyMs: 1)).code, 40901);
  });
}
