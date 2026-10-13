import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/screens/dashboard/dashboard_screen.dart';

void main() {
  test('a section metric is hidden when its permission is absent', () {
    expect(
      dashboardMetricIsVisible(
        allowedSections: const {'dashboard'},
        hasMetric: true,
        section: 'payments_management',
      ),
      isFalse,
    );
  });

  test('a section metric is visible only when supplied and authorized', () {
    expect(
      dashboardMetricIsVisible(
        allowedSections: const {'dashboard', 'tables'},
        hasMetric: true,
        section: 'tables',
      ),
      isTrue,
    );
    expect(
      dashboardMetricIsVisible(
        allowedSections: const {'dashboard', 'tables'},
        hasMetric: false,
        section: 'tables',
      ),
      isFalse,
    );
  });

  test('a metric without an owning section is denied by default', () {
    expect(
      dashboardMetricIsVisible(
        allowedSections: const {'dashboard'},
        hasMetric: true,
      ),
      isFalse,
    );
  });
}
