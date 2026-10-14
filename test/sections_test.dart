import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/app/section_registry.dart';

void main() { test('exactly 34 unique management sections', () {
  expect(cafeSections.length, 34);
  expect(cafeSections.map((e) => e.id).toSet().length, 34);
}); }
