/// Projects the existing kitchen-order report into measured preparation times.
/// Missing timestamps are excluded from statistics, never treated as zero.
Map<String,dynamic> cafeServiceSpeedReport(Map<String,dynamic> report) {
  final columns = List<String>.from(report['columns'] as List);
  final required = ['Order','Created (Baghdad)','Source','Table / destination','Status','Minutes to ready'];
  final indexes = required.map(columns.indexOf).toList();
  if (indexes.any((i)=>i<0)) throw const FormatException('Timing fields unavailable');
  final rows = <List<dynamic>>[], measured = <double>[];
  var cancelled = 0;
  for (final raw in report['rows'] as List) {
    final row = raw as List;
    if (row.length != columns.length) throw const FormatException('Invalid timing record');
    if (row[indexes[4]] == 'cancelled') { cancelled++; continue; }
    final value = row[indexes[5]];
    final minutes = value is num && value.isFinite && value >= 0 ? value.toDouble() : null;
    if (minutes != null) measured.add(minutes);
    rows.add([for (final index in indexes.take(5)) row[index], minutes]);
  }
  measured.sort();
  final average = measured.isEmpty ? null : measured.reduce((a,b)=>a+b)/measured.length;
  final median = measured.isEmpty ? null : measured.length.isOdd
    ? measured[measured.length~/2]
    : (measured[measured.length~/2-1]+measured[measured.length~/2])/2;
  return {...report,
    'columns':required, 'rows':rows,
    'note':'Receipt to first recorded ready event. ${measured.length} measured orders; '
      '${rows.length-measured.length} without usable timing; $cancelled cancelled orders excluded. '
      'Average: ${average?.toStringAsFixed(1) ?? 'Not recorded'} min. '
      'Median: ${median?.toStringAsFixed(1) ?? 'Not recorded'} min. '
      'Statistics cover the full selected period before search/filters. '
      'Delivery and staff response times are not measured by this report.',
  };
}
