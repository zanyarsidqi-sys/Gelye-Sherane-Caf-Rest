import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/app/section_registry.dart';

void main() { test('exactly 35 unique management sections', () {
  expect(cafeSections.length, 35);
  expect(cafeSections.map((e) => e.id).toSet().length, 35);
}); }
