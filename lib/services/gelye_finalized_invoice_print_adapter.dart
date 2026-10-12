import '../shared/gelye_invoice_templates.dart';
import 'gelye_invoice_print_boundary.dart';

/// Immutable input obtained by an authenticated Finance invoice-read operation.
/// Never construct this from client cart totals, mutable menu prices, or a
/// Kitchen print ticket. This adapter performs no writes or payment capture.
class GelyeFinalizedInvoiceSnapshot {
  const GelyeFinalizedInvoiceSnapshot({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.finalizedAt,
    required this.companyName,
    required this.currency,
    required this.paymentStatus,
    required this.totalMinor,
    required this.lines,
    required this.isFinalized,
    this.buyerName,
    this.companyAddress,
    this.companyRegistration,
    this.taxIdentifier,
    this.notes,
  });
  final String invoiceId, invoiceNumber, companyName, currency, paymentStatus;
  final DateTime finalizedAt;
  final int totalMinor;
  final List<GelyeInvoiceLine> lines;
  final bool isFinalized;
  final String? buyerName, companyAddress, companyRegistration, taxIdentifier, notes;
}

class GelyeInvoicePrintOutputs {
  const GelyeInvoicePrintOutputs({required this.invoiceId,
    required this.invoiceNumber, required this.posText, required this.a4Data});
  final String invoiceId, invoiceNumber, posText;
  final Map<String, Object?> a4Data;
}

/// One validated invoice identity supplies BOTH formats. No finance mutation.
/// Caller must fetch a finalized invoice from an authorized server-side source.
class GelyeFinalizedInvoicePrintAdapter {
  const GelyeFinalizedInvoicePrintAdapter();

  GelyeInvoicePrintOutputs prepare(GelyeFinalizedInvoiceSnapshot snapshot) {
    if (!snapshot.isFinalized) {
      throw StateError('Invoice is not finalized');
    }
    // Defensive copy: no later changes to the caller's list can alter one
    // format without the other during preparation.
    final lines = List<GelyeInvoiceLine>.unmodifiable(snapshot.lines);
    final document = GelyeInvoiceDocument(
      invoiceId: snapshot.invoiceId,
      number: snapshot.invoiceNumber,
      issuedAt: snapshot.finalizedAt,
      companyName: snapshot.companyName,
      currency: snapshot.currency,
      paymentStatus: snapshot.paymentStatus,
      totalMinor: snapshot.totalMinor,
      lines: lines,
      buyerName: snapshot.buyerName,
      companyAddress: snapshot.companyAddress,
      companyRegistration: snapshot.companyRegistration,
      taxIdentifier: snapshot.taxIdentifier,
      notes: snapshot.notes,
    );
    const boundary = GelyeInvoicePrintBoundary();
    final approved = boundary.requireFinalized(
      document: document,
      authoritativeInvoiceId: snapshot.invoiceId,
      authoritativeInvoiceNumber: snapshot.invoiceNumber,
      isFinalized: snapshot.isFinalized,
    );
    return GelyeInvoicePrintOutputs(
      invoiceId: approved.invoiceId,
      invoiceNumber: approved.number,
      posText: boundary.posReceipt(approved),
      a4Data: Map<String, Object?>.unmodifiable(boundary.a4Document(approved)),
    );
  }
}
