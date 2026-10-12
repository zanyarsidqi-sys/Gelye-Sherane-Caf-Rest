import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/screens/dashboard/payment_confirmation_models.dart';

void main() {
  test('pending credit requires receiver verification', () {
    final payment = PaymentReviewRecord.fromJson({
      'id': 'payment-1', 'order_id': 'order-1', 'amount_iqd': 12500,
      'method': 'credit', 'status': 'pending',
    });
    expect(payment.requiresReceiverVerification, isTrue);
    expect(payment.amountIqd, 12500);
  });
  test('online screenshot does not mark payment approved', () {
    final payment = PaymentReviewRecord.fromJson({
      'id': 'payment-2', 'order_id': 'order-2', 'amount_iqd': 20000,
      'method': 'fastpay', 'evidence_path': 'private/evidence.png',
    });
    expect(payment.requiresReceiverVerification, isTrue);
  });
  test('invalid amounts rejected', () {
    expect(() => PaymentReviewRecord.fromJson({
      'id': 'p', 'order_id': 'o', 'amount_iqd': -1, 'method': 'credit',
    }), throwsFormatException);
  });
}
