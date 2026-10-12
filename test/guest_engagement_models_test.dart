import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/screens/dashboard/guest_engagement_models.dart';

void main() {
  test('guest name is optional', () {
    const draft = GuestFeedbackDraft(category: 'Concern', message: 'Slow service');
    expect(draft.validate(), isNull);
    expect(draft.toPayload()['customer_name'], isNull);
  });
  test('invalid rating rejected', () {
    const draft = GuestFeedbackDraft(category: 'Concern', message: 'Service', rating: 6);
    expect(draft.validate(), isNotNull);
  });
  test('recommendations require a reason', () {
    const draft = ProductRecommendationDraft(type: 'Suggest new product',
      productName: 'Fresh lemonade', reason: ' ');
    expect(draft.validate(), isNotNull);
  });
}
