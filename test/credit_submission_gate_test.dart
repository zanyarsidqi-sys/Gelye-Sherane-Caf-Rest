import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/shared/credit_submission_gate.dart';

void main() {
  test('local drafts cannot submit a withdrawal', () {
    expect(CreditSubmissionGate.canSubmitFromLocalDraft(), isFalse);
  });
  test('submission checklist covers server balance and duplicate posting', () {
    expect(CreditSubmissionGate.requiredChecks.any((v) => v.contains('balance')), isTrue);
    expect(CreditSubmissionGate.requiredChecks.any((v) => v.contains('duplicate')), isTrue);
    expect(CreditSubmissionGate.requiredChecks.any((v) => v.contains('approval')), isTrue);
  });
}
