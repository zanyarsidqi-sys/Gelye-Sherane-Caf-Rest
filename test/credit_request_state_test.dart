import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/shared/credit_request_state.dart';

void main() {
  test('draft can only request approval or cancel', () {
    expect(CreditRequestState.canTransition(CreditRequestStatus.draft,
        CreditRequestStatus.pendingApproval), isTrue);
    expect(CreditRequestState.canTransition(CreditRequestStatus.draft,
        CreditRequestStatus.posted), isFalse);
  });
  test('rejected and cancelled requests cannot post', () {
    for (final state in [CreditRequestStatus.rejected, CreditRequestStatus.cancelled]) {
      expect(CreditRequestState.canTransition(state, CreditRequestStatus.posted), isFalse);
    }
  });
  test('only posted transactions are settled', () {
    expect(CreditRequestState.isSettled(CreditRequestStatus.approved), isFalse);
    expect(CreditRequestState.isSettled(CreditRequestStatus.posted), isTrue);
  });
  test('posted request can only be reversed', () {
    expect(CreditRequestState.canTransition(CreditRequestStatus.posted,
        CreditRequestStatus.reversed), isTrue);
    expect(CreditRequestState.canTransition(CreditRequestStatus.posted,
        CreditRequestStatus.cancelled), isFalse);
  });
}
