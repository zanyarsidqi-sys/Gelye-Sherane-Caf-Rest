import 'package:flutter_test/flutter_test.dart';
import '../lib/app/section_registry.dart';
import '../lib/app/management_group_registry.dart';

void main() {
  test('35 original section keys appear once in 11 ordered groups', () {
    expect(managementGroups.length, 11);
    expect(managementGroups.first.id, 'dashboard');
    expect(managementGroups.last.id, 'operations');
    final original = cafeSections.map((s) => s.id).toList();
    final mapped = managementGroups.expand((g) => g.sectionIds).toList();
    expect(original.length, 35);
    expect(original.toSet().length, 35);
    expect(mapped.length, 35);
    expect(mapped.toSet(), original.toSet());
    expect(mapped.toSet().length, mapped.length);
    expect(managementGroups.singleWhere((g) => g.id == 'settings_group').sectionIds.length, 12);
  });
}
