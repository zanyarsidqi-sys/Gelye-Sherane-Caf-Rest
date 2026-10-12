import '../shared/gelye_invoice_templates.dart';

/// Read-only reconciliation at the Table Orders / Kitchen / Finance boundary.
/// No payments, invoice inserts, or credit deductions are performed here.
class GelyeInvoicePrintBoundary {
  const GelyeInvoicePrintBoundary();

  /// Refuse printing if an invoice is not finalized or identity mismatches.
  /// The authoritative finance API must provide the expected invoice identity.
  GelyeInvoiceDocument requireFinalized({
    required GelyeInvoiceDocument document,
    required String authoritativeInvoiceId,
    required String authoritativeInvoiceNumber,
    required bool isFinalized,
  }) {
    if (!isFinalized || authoritativeInvoiceId.trim().isEmpty ||
        authoritativeInvoiceNumber.trim().isEmpty ||
        document.invoiceId != authoritativeInvoiceId ||
        document.number != authoritativeInvoiceNumber) {
      throw StateError('Invoice not finalized or identity mismatch');
    }
    document.validate();
    return document;
  }

  // Rendering alone does not establish finalization; callers must first use
  // requireFinalized with trusted server-side invoice identity.
  String posReceipt(GelyeInvoiceDocument doc) {
    doc.validate();
    return GelyePosReceiptTemplate.render(doc);
  }

  Map<String,Object?> a4Document(GelyeInvoiceDocument doc) {
    doc.validate();
    return GelyeA4OfficialInvoiceTemplate.build(doc);
  }
}
