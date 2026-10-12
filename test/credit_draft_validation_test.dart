import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/shared/credit_draft_validation.dart';

void main() {
  test('amount must be positive whole IQD', () {
    expect(CreditDraftValidation.amountIqd('1000'), isNull);
    expect(CreditDraftValidation.amountIqd('0'), isNotNull);
    expect(CreditDraftValidation.amountIqd('-10'), isNotNull);
    expect(CreditDraftValidation.amountIqd('10.5'), isNotNull);
    expect(CreditDraftValidation.amountIqd('abc'), isNotNull);
  });

  test('motel order always resolves to tourism mode', () {
    expect(CreditDraftValidation.effectiveMode('Motel Order', 'Normal'), 'Tourism');
    expect(CreditDraftValidation.effectiveMode('Table Order', 'Normal'), 'Normal');
  });

  test('barcode is masked in review', () {
    expect(CreditDraftValidation.maskedBarcode('123456789'), '*****6789');
    expect(CreditDraftValidation.maskedBarcode('123'), '***');
  });
}
