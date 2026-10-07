import 'package:flutter_test/flutter_test.dart';
import 'package:xinguang_cloud/services/api_gateway.dart';
import 'package:xinguang_cloud/services/mock_db.dart';

void main() {
  test('consumption offset -> debt points -> bank clearance -> certificate', () async {
    final api = ApiGateway.instance;
    final db = MockDb.instance;
    api.setSession('U1001');
    final r0 = await api.call('POST', '/v1/debt-cases/import/manual', body: {'source': 'user_manual', 'creditor': '测试小贷', 'amount': 40.0, 'debt_type': 'privateDebt'}, latencyMs: 1);
    expect(r0.code, 0);
    final caseId = r0.data['case_id'] as String;
    final r1 = await api.call('POST', '/v1/shop/orders', body: {'sku_id': 'SKU-MOVIE', 'channel': 'wechat'}, latencyMs: 1);
    expect(r1.code, 0);
    expect(r1.data['debt_points_issued'], 25.0);
    final before = api.availablePoints('U1001');
    await api.call('POST', '/v1/auth/pay-password/verify', body: {'pay_password': '888888'}, latencyMs: 1);
    final r2 = await api.call('POST', '/v1/clearance/submit', body: {'case_id': caseId, 'points': 40.0}, requirePayToken: true, latencyMs: 1);
    expect(r2.code, 0, reason: r2.message);
    expect(api.availablePoints('U1001'), closeTo(before - 40, 0.01));
    await Future.delayed(const Duration(milliseconds: 6500));
    final c = db.debtCases.firstWhere((c) => c.caseId == caseId);
    expect(c.outstanding, 0);
    expect(c.status, 3);
    expect(c.certificateId, isNotNull);
    expect(db.certificates.firstWhere((x) => x.caseId == caseId).bankName, '测试小贷');
    double d = 0, cr = 0;
    for (final e in db.ledger) {
      e.direction == 'D' ? d += e.amount : cr += e.amount;
    }
    expect((d - cr).abs() < 0.01, true);
    final r3 = await api.call('POST', '/v1/clearance/submit', body: {'case_id': caseId, 'points': 1.0}, requirePayToken: true, latencyMs: 1);
    expect(r3.code, 40901);
  });
}
