import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/app/section_registry.dart';

void main() {
  test('exactly 26 unique visible management sections', () {
    expect(cafeSections.length, 26);
    expect(cafeSections.map((e) => e.id).toSet().length, 26);
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

  test('Kitchen groups the four work areas without replacing their grants', () {
    final ids = cafeSections.map((section) => section.id).toSet();
    final kitchen = cafeSections.singleWhere((section) => section.id == 'kitchen');
    expect(
      kitchen.additionalAccessSectionIds.toSet(),
      {'menu', 'products_inventory', 'nargile_management'},
    );
    expect(
      ids.intersection({'menu', 'products_inventory', 'nargile_management'}),
      isEmpty,
    );
    expect(
      kitchen.isVisibleTo({'products_inventory'}),
      isTrue,
    );
    expect(
      kitchen.isVisibleTo({'kitchen'}),
      isTrue,
    );
  });
}
