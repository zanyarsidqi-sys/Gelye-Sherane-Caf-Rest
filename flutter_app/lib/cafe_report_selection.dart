/// Read-only selection shared by screen and PDF export. Never mutates source rows.
List<String> cafeReportOptions(List<String> columns, List<List<dynamic>> rows, String column) {
  final index = columns.indexOf(column);
  if (index < 0) return const [];
  return rows.where((row) => row[index] != null && '${row[index]}'.isNotEmpty)
      .map((row) => '${row[index]}').toSet().toList()..sort();
}

List<List<dynamic>> selectCafeReportRows({
  required List<String> columns,
  required List<List<dynamic>> rows,
  String query = '',
  Map<String, String> filters = const {},
  int? sortColumn,
  bool ascending = true,
}) {
  final selected = rows.asMap().entries.where((entry) {
    final row = entry.value;
    if (!row.join(' ').toLowerCase().contains(query.trim().toLowerCase())) return false;
    for (final filter in filters.entries) {
      final index = columns.indexOf(filter.key);
      if (index < 0 || '${row[index]}' != filter.value) return false;
    }
    return true;
  }).toList();
  if (sortColumn != null && sortColumn >= 0 && sortColumn < columns.length) {
    selected.sort((a, b) {
      final left = a.value[sortColumn], right = b.value[sortColumn];
      // Missing values stay last in either direction. Equal values preserve server order.
      if (left == null && right != null) return 1;
      if (right == null && left != null) return -1;
      final comparison = left == null ? 0 : left is num && right is num
          ? left.compareTo(right) : '$left'.toLowerCase().compareTo('$right'.toLowerCase());
      return comparison == 0 ? a.key.compareTo(b.key) : ascending ? comparison : -comparison;
    });
  }
  return selected.map((entry) => List<dynamic>.from(entry.value)).toList();
}
