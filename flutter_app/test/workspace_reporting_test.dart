import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/workspace_reporting.dart';

DateTime baghdadInstant(
  int year, [
  int month = 1,
  int day = 1,
  int hour = 0,
  int minute = 0,
]) => DateTime.utc(
  year,
  month,
  day,
  hour,
  minute,
).subtract(const Duration(hours: 3));

void main() {
  test(
    'Baghdad dates and day boundaries are independent of device timezone',
    () {
      expect(
        baghdadCalendarDate(DateTime.parse('2026-10-16T21:00:00Z')),
        DateTime.utc(2026, 10, 17),
      );
      final range = WorkspaceReportRange.forSelection(
        DateTime.utc(2026, 10, 17),
        'Today',
      );
      expect(range.start, DateTime.parse('2026-10-16T21:00:00Z'));
      expect(range.contains(DateTime.parse('2026-10-16T20:59:59Z')), isFalse);
      expect(
        range.contains(DateTime.parse('2026-10-17T23:59:59+03:00')),
        isTrue,
      );
      expect(
        range.contains(DateTime.parse('2026-10-18T00:00:00+03:00')),
        isFalse,
      );
    },
  );
  test('report windows include start and exclude end', () {
    final range = WorkspaceReportRange.forSelection(
      DateTime(2026, 10, 17),
      'Today',
    );
    expect(range.contains(baghdadInstant(2026, 10, 17)), isTrue);
    expect(range.contains(baghdadInstant(2026, 10, 16, 23, 59)), isFalse);
    expect(range.contains(baghdadInstant(2026, 10, 18)), isFalse);
  });

  test('yesterday and week handle month and year boundaries', () {
    final yesterday = WorkspaceReportRange.forSelection(
      DateTime(2027),
      'Yesterday',
    );
    expect(yesterday.start, baghdadInstant(2026, 12, 31));
    expect(yesterday.end, baghdadInstant(2027));
    final week = WorkspaceReportRange.forSelection(DateTime(2027), 'This Week');
    expect(week.start, baghdadInstant(2026, 12, 28));
    expect(week.end, baghdadInstant(2027, 1, 4));
  });

  test('month covers leap day and excludes next month', () {
    final month = WorkspaceReportRange.forSelection(
      DateTime(2028, 2, 10),
      'This Month',
    );
    expect(month.contains(baghdadInstant(2028, 2, 29, 23, 59)), isTrue);
    expect(month.contains(baghdadInstant(2028, 3)), isFalse);
  });

  test('amount summaries preserve precision and never mix currencies', () {
    expect(workspaceAmountLabel([]), '—');
    expect(workspaceAmountLabel([(amount: null, currency: 'IQD')]), '—');
    expect(
      workspaceAmountLabel([
        (amount: 100.25, currency: 'IQD'),
        (amount: -10.0, currency: 'IQD'),
      ]),
      '90.25 IQD',
    );
    expect(
      workspaceAmountLabel([
        (amount: 100.0, currency: 'IQD'),
        (amount: 5.0, currency: 'USD'),
      ]),
      'Multiple currencies',
    );
    expect(workspaceAmountLabel([(amount: double.nan, currency: 'IQD')]), '—');
  });
}
