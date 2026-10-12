import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/services/device_session_preference.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12);
  Map<String, dynamic> record({String mode = 'timed', int? expiry}) => {
    'user': 'employee-a', 'session': 'login-a', 'mode': mode,
    'expires': expiry ?? now.add(const Duration(hours: 8)).millisecondsSinceEpoch,
  };
  test('saved device remains valid within chosen duration', () {
    expect(DeviceSessionPreference.accepts(record(), 'employee-a', 'login-a', now), isTrue);
  });
  test('expiry is absolute and rejected exactly at the deadline', () {
    expect(DeviceSessionPreference.accepts(record(expiry: now.millisecondsSinceEpoch), 'employee-a', 'login-a', now), isFalse);
  });
  test('same employee new login cannot inherit old session preference', () {
    expect(DeviceSessionPreference.accepts(record(), 'employee-a', 'login-b', now), isFalse);
  });
  test('another employee cannot inherit remembered device authorization', () {
    expect(DeviceSessionPreference.accepts(record(), 'employee-b', 'login-a', now), isFalse);
  });
  test('until logout has no local deadline', () {
    final saved = record(mode: 'logout')..['expires'] = null;
    expect(DeviceSessionPreference.accepts(saved, 'employee-a', 'login-a', now.add(const Duration(days: 365))), isTrue);
  });
  test('missing or malformed preference fails closed', () {
    expect(DeviceSessionPreference.accepts(null, 'employee-a', 'login-a', now), isFalse);
    expect(DeviceSessionPreference.accepts(record(mode: 'unknown'), 'employee-a', 'login-a', now), isFalse);
    expect(DeviceSessionPreference.accepts(record(), 'employee-a', null, now), isFalse);
  });
}
