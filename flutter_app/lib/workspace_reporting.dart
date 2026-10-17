/// Baghdad currently observes UTC+03:00 year-round. The selected date is a
/// calendar date; stored boundaries and comparisons use UTC instants.
/// Revisit this offset if Iraq changes its civil-time rules.
DateTime baghdadCalendarDate(DateTime instant) {
  final local = instant.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(local.year, local.month, local.day);
}

class WorkspaceReportRange {
  const WorkspaceReportRange(this.start, this.end);

  factory WorkspaceReportRange.forSelection(DateTime date, String selection) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final start = switch (selection) {
      'Yesterday' => DateTime.utc(day.year, day.month, day.day - 1),
      'This Week' => DateTime.utc(
        day.year,
        day.month,
        day.day - day.weekday + 1,
      ),
      'This Month' => DateTime.utc(day.year, day.month),
      'This Year' => DateTime.utc(day.year),
      _ => day,
    };
    final end = switch (selection) {
      'This Week' => DateTime.utc(start.year, start.month, start.day + 7),
      'This Month' => DateTime.utc(start.year, start.month + 1),
      'This Year' => DateTime.utc(start.year + 1),
      _ => DateTime.utc(start.year, start.month, start.day + 1),
    };
    return WorkspaceReportRange(
      start.subtract(const Duration(hours: 3)),
      end.subtract(const Duration(hours: 3)),
    );
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime timestamp) =>
      !timestamp.isBefore(start) && timestamp.isBefore(end);
}

/// Never combines different currencies or silently converts them.
String workspaceAmountLabel(
  Iterable<({double? amount, String currency})> rows,
) {
  final totals = <String, double>{};
  for (final row in rows) {
    final amount = row.amount;
    if (amount == null || !amount.isFinite) continue;
    totals.update(
      row.currency,
      (value) => value + amount,
      ifAbsent: () => amount,
    );
  }
  if (totals.isEmpty) return '—';
  if (totals.length > 1) return 'Multiple currencies';
  final entry = totals.entries.single;
  // These are manually entered record amounts, not settled financial totals.
  return '${entry.value.toStringAsFixed(2)} ${entry.key}';
}
