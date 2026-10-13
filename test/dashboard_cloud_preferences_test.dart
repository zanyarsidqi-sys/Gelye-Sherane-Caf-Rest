import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/screens/dashboard/dashboard_cloud_preferences.dart';

void main() {
  test('cloud preference snapshot validates object and revision', () {
    final snapshot = DashboardPreferenceSnapshot.fromJson({
      'preferences': {'order': ['orders', 'cash']},
      'revision': 12,
      'updated_at': '2026-10-13T10:00:00Z',
    });

    expect(snapshot.revision, 12);
    expect(snapshot.preferences['order'], ['orders', 'cash']);
  });

  test('cloud preference snapshot rejects malformed revisions and payloads', () {
    expect(
      () => DashboardPreferenceSnapshot.fromJson({
        'preferences': [],
        'revision': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => DashboardPreferenceSnapshot.fromJson({
        'preferences': {},
        'revision': -1,
      }),
      throwsFormatException,
    );
  });
}
