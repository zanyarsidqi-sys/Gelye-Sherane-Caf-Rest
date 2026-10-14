/// A4 invoice data must come from a finalized authoritative invoice record.
/// This is a template specification, not a tax-certified document renderer.
class GelyeOfficialInvoiceLayout {
  static const paperWidthMm=210;
  static const paperHeightMm=297;
  static const requiredFields=<String>[
    'invoice_number','issued_at','company_legal_name','company_address',
    'buyer_name','line_items','currency','total_minor','payment_status',
  ];
  static void validate(Map<String,dynamic> invoice) {
    for (final key in requiredFields) {
      if (!invoice.containsKey(key) || invoice[key]==null ||
          (invoice[key] is String && (invoice[key] as String).trim().isEmpty)) {
        throw StateError('Official invoice missing $key');
      }
    }
    if (invoice['paper'] != 'A4' || invoice['total_minor'] is! int ||
        (invoice['total_minor'] as int) < 0 ||
        invoice['line_items'] is! List ||
        (invoice['line_items'] as List).isEmpty) {
      throw StateError('Invalid A4 invoice structure');
    }
  }
}
