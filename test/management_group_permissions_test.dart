import 'package:flutter_test/flutter_test.dart';
import '../lib/app/management_group_registry.dart';

void main() {
  test('a parent group grants no extra child permissions', () {
    final allowed = <String>{'dashboard', 'menu', 'revenue'};
    final visible = allowedManagementGroups(allowed);
    expect(visible.map((g) => g.id).toList(), <String>['dashboard', 'payment', 'kitchen_group']);
    final kitchen = visible.singleWhere((g) => g.id == 'kitchen_group');
    expect(allowedGroupChildren(kitchen, allowed).map((s) => s.id).toList(), <String>['menu']);
    final payment = visible.singleWhere((g) => g.id == 'payment');
    expect(allowedGroupChildren(payment, allowed).map((s) => s.id).toList(), <String>['revenue']);
  });
  test('empty permission set shows no groups or children', () {
    expect(allowedManagementGroups(<String>{}), isEmpty);
    for (final group in managementGroups) {
      expect(allowedGroupChildren(group, <String>{}), isEmpty);
    }
  });
}
