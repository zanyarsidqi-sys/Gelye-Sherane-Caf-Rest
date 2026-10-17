/// Exact whole-IQD totals for the selected ledger rows. Refunds are separate
/// transactions, never negative payments or edits to the original receipt.
Map<String, BigInt> cafeReceiptTotals(List<String> columns, List<List<dynamic>> rows) {
  final kind = columns.indexOf('Kind');
  final amount = columns.indexOf('Amount IQD');
  final transaction = columns.indexOf('Transaction');
  if (kind < 0 || amount < 0 || transaction < 0) {
    throw const FormatException('Missing receipt columns');
  }
  var payments = BigInt.zero, refunds = BigInt.zero;
  final seen = <String>{};
  for (final row in rows) {
    if (row.length != columns.length || row[transaction] is! String ||
        (row[transaction] as String).trim().isEmpty ||
        !seen.add(row[transaction] as String)) {
      throw const FormatException('Invalid or duplicate receipt');
    }
    final raw = row[amount];
    if (raw is! int && raw is! String) throw const FormatException('Invalid IQD amount');
    // JSON numbers larger than the exact JavaScript integer range are unsafe.
    if (raw is int && raw > 9007199254740991) throw const FormatException('Unsafe IQD amount');
    final text = '$raw';
    if (!RegExp(r'^[0-9]+$').hasMatch(text)) throw const FormatException('Invalid IQD amount');
    final value = BigInt.parse(text);
    if (row[kind] == 'payment') {
      payments += value;
    } else if (row[kind] == 'refund') {
      refunds += value;
    } else {
      throw const FormatException('Unknown receipt kind');
    }
  }
  return {'payments': payments, 'refunds': refunds, 'net': payments - refunds};
}

String cafeReceiptSummary(List<String> columns, List<List<dynamic>> rows) {
  final totals = cafeReceiptTotals(columns, rows);
  return 'Filtered payments: ${totals['payments']} IQD · Refunds: ${totals['refunds']} IQD · Net received: ${totals['net']} IQD';
}
