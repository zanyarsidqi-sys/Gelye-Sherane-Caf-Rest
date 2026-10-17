import 'dart:async';
import 'package:gelye_sherane_cafe/cafe_language.dart';

// Existing workflow fixtures explicitly use English. Language tests separately
// verify the real default (Badini), saved preferences, and RTL switching.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  cafeLanguage.language = CafeLanguage.english;
  await testMain();
}
