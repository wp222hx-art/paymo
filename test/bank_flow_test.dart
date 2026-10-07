import 'package:flutter_test/flutter_test.dart';
import 'package:xinguang_cloud/services/api_gateway.dart';
import 'package:xinguang_cloud/services/mock_db.dart';

void main() {
  test('bank officer manual clearance: accept -> confirm -> write-off -> certificate; reject rollback; tenant isolation', () async {
    final api = ApiGateway.instance;
    final db = MockDb.instance;

    // 用户侧：录一笔招行小额案件并提交积分（招行有专员 → 停在 10）
    api.setSession('U1001');
    final r0 = await api.call('POST', '/v1/debt-cases/import/manual', body: {'source': 'user_manual', 'creditor': '招商银行信用卡中心', 'amount': 30.0, 'debt_type': 'creditCard'}, latencyMs: 1);
    final caseId = r0.data['case_id'] as String;
    await api.call('POST', '/v1/auth/pay-password/verify', body: {'pay_password': '888888'}, latencyMs: 1);
    final r1 = await api.call('POST', '/v1/clearance/submit', body: {'case_id': caseId, 'points': 30.0}, requirePayToken: true, latencyMs: 1);
    expect(r1.code, 0, reason: r1.message);
    expect(r1.data['processing'], 'manual (bank officer)');
    final clId = r1.data['clearance_id'] as String;
    await Future.delayed(const Duration(milliseconds: 100));
    expect(db.clearances.firstWhere((c) => c.clearanceId == clId).status, 10);

    // 非银行角色调用银行 API → 40303
    final rx = await api.call('POST', '/v1/bank/clearances/$clId/accept', latencyMs: 1);
    expect(rx.code, 40303);

    // 银行专员
    api.setSession('U1006');
    // 跨租户：交行单子不可操作
    final rt = await api.call('POST', '/v1/bank/clearances/CL8001/accept', latencyMs: 1);
    expect(rt.code, 40303);
    // 顺序校验：未受理直接核销 → 40901
    final rw = await api.call('POST', '/v1/bank/clearances/$clId/write-off', latencyMs: 1);
    expect(rw.code, 40901);
    expect((await api.call('POST', '/v1/bank/clearances/$clId/accept', latencyMs: 1)).code, 0);
    expect((await api.call('POST', '/v1/bank/clearances/$clId/confirm-remit', latencyMs: 1)).code, 0);
    final rwo = await api.call('POST', '/v1/bank/clearances/$clId/write-off', body: {'accept_reduction': true}, latencyMs: 1);
    expect(rwo.code, 0);
    expect(rwo.data['case_cleared'], true);
    final rc = await api.call('POST', '/v1/bank/clearances/$clId/issue-certificate', latencyMs: 1);
    expect(rc.code, 0);
    final cert = db.certificates.firstWhere((c) => c.caseId == caseId);
    expect(cert.issuedBy, '顾承业');
    expect(db.debtCases.firstWhere((c) => c.caseId == caseId).status, 3);

    // 退回回滚：CL8002 退回后用户积分恢复
    api.setSession('U1001');
    final before = api.availablePoints('U1001');
    api.setSession('U1006');
    final rr = await api.call('POST', '/v1/bank/clearances/CL8002/reject', body: {'reason': '测试退回'}, latencyMs: 1);
    expect(rr.code, 0);
    expect(api.availablePoints('U1001'), closeTo(before + 462.4, 0.01));

    // 账本平衡
    double d = 0, c = 0;
    for (final e in db.ledger) {
      e.direction == 'D' ? d += e.amount : c += e.amount;
    }
    expect((d - c).abs() < 0.01, true);
  });
}
