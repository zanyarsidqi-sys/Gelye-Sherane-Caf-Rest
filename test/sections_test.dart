import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/app/section_registry.dart';

void main() {
  test('exactly 29 unique visible management sections', () {
    expect(cafeSections.length, 29);
    expect(cafeSections.map((e) => e.id).toSet().length, 29);
  });

  test('finance areas share one visible Payment Management entry', () {
    final ids = cafeSections.map((section) => section.id).toSet();
    expect(ids, contains('payments_management'));
    expect(
      ids.intersection({
        'cost',
        'revenue',
        'invoices_payments',
        'discount_management',
        'credit_management',
      }),
      isEmpty,
    );
  });
}
