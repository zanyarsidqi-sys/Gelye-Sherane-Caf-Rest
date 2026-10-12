import 'gelye_company_footer.dart';

/// Read-only document rendering. Both formats use the same authoritative invoice.
/// Do not call a payment capture endpoint from a print action.
/// Prevent embedded newlines/control characters from forging receipt rows.
String _invoicePrintable(String value) => value
    .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class GelyeInvoiceDocument {
  GelyeInvoiceDocument({required this.invoiceId, required this.number,
    required this.issuedAt,required this.companyName,required this.currency,
    required this.lines,required this.totalMinor,required this.paymentStatus,
    this.buyerName,this.companyAddress,this.companyRegistration,
    this.taxIdentifier,this.notes});
  final String invoiceId,number,companyName,currency,paymentStatus;
  final DateTime issuedAt;
  final List<GelyeInvoiceLine> lines;
  final int totalMinor;
  final String? buyerName,companyAddress,companyRegistration,taxIdentifier,notes;
  /// Both print formats are read-only views of this same finalized invoice ID.
  void validate() {
    if (invoiceId.trim().isEmpty || number.trim().isEmpty ||
        companyName.trim().isEmpty || currency.trim().isEmpty || lines.isEmpty ||
        totalMinor<0 || paymentStatus.trim().isEmpty ||
        issuedAt.year < 2000 || issuedAt.year > 2200) throw StateError('Invalid finalized invoice');
    for (final line in lines) {
      if (line.description.trim().isEmpty || line.quantity<=0 || line.quantity>100000 || line.totalMinor<0) {
        throw StateError('Invalid invoice line');
      }
    }
  }
}
class GelyeInvoiceLine {
  const GelyeInvoiceLine(this.description,this.quantity,this.totalMinor);
  final String description;
  final int quantity,totalMinor;
}

/// Plain-text 80mm printer data. A real driver must implement printer encoding.
class GelyePosReceiptTemplate {
  static String render(GelyeInvoiceDocument doc) {
    doc.validate();
    final b=StringBuffer()
      ..writeln(_invoicePrintable(doc.companyName))
      ..writeln('Receipt / Invoice ${_invoicePrintable(doc.number)}')
      ..writeln('Date: ${doc.issuedAt.toIso8601String()}')
      ..writeln('--------------------------------');
    for (final line in doc.lines) {
      b.writeln('${line.quantity} x ${_invoicePrintable(line.description)}: ${line.totalMinor} ${_invoicePrintable(doc.currency)}');
    }
    b..writeln('--------------------------------')
      ..writeln('Total: ${doc.totalMinor} ${doc.currency}')
      ..writeln('Payment: ${_invoicePrintable(doc.paymentStatus)}')
      ..writeln(gelyeBillPoweredBy);
    return b.toString();
  }
}

/// Structured A4 layout model for a future PDF/print adapter; not a certified tax invoice.
class GelyeA4OfficialInvoiceTemplate {
  static const pageWidthMm=210, pageHeightMm=297;
  static Map<String,Object?> build(GelyeInvoiceDocument doc) {
    doc.validate();
    return <String,Object?>{
      'paper':'A4', 'width_mm':pageWidthMm,'height_mm':pageHeightMm,
      'invoice_id':doc.invoiceId,'invoice_number':doc.number,
      'issued_at':doc.issuedAt.toIso8601String(),
      'company_legal_name':_invoicePrintable(doc.companyName),
      'company_address':doc.companyAddress,
      'company_registration':doc.companyRegistration,
      'tax_identifier':doc.taxIdentifier,'buyer_name':doc.buyerName == null ? null : _invoicePrintable(doc.buyerName!),
      'line_items':[for (final l in doc.lines)
        {'description':_invoicePrintable(l.description),'quantity':l.quantity,'total_minor':l.totalMinor}],
      'currency':doc.currency,'total_minor':doc.totalMinor,
      'payment_status':doc.paymentStatus,'notes':doc.notes,
      'signature_and_stamp_space':true,'footer':gelyeBillPoweredBy,
    };
  }
}
