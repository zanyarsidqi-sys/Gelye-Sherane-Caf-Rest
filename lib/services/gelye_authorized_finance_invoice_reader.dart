import 'package:supabase_flutter/supabase_flutter.dart';
import 'gelye_finalized_invoice_print_adapter.dart';
import '../shared/gelye_invoice_templates.dart';

/// Finance-only read boundary. Does not post invoices, capture payments or
/// assume that a posted motel-food invoice is a finalized paid invoice.
class GelyeAuthorizedFinanceInvoiceReader {
  const GelyeAuthorizedFinanceInvoiceReader(this.client);
  final SupabaseClient client;

  Future<GelyeFinalizedInvoiceSnapshot> readMotelInvoice({
    required String invoiceId,
    required String companyLegalName,
  }) async {
    if (invoiceId.trim().isEmpty || companyLegalName.trim().isEmpty) {
      throw ArgumentError('Invoice ID and company legal name required');
    }
    final response = await client.rpc('gs_staff_read_motel_finance_print_snapshot',
      params: {'p_invoice_id': invoiceId.trim()});
    if (response is! Map) throw StateError('Invalid Finance invoice response');
    final data = Map<String, dynamic>.from(response);
    final rawLines = data['lines'];
    if (rawLines is! List) throw StateError('Invoice lines unavailable');
    final lines = rawLines.map((item) {
      if (item is! Map) throw StateError('Invalid invoice line');
      final line = Map<String, dynamic>.from(item);
      final quantity = line['quantity'];
      final total = line['total_minor'];
      if (quantity is! int || total is! int) {
        throw StateError('Invalid invoice amounts');
      }
      return GelyeInvoiceLine(line['description'] as String, quantity, total);
    }).toList(growable: false);
    final finalized = data['is_finalized'];
    // This RPC deliberately returns false for posted/unpaid motel invoices.
    // The print adapter rejects them until a separate authoritative Finance
    // finalization source is implemented and verified.
    if (finalized != false) throw StateError('Unexpected finalization state');
    return GelyeFinalizedInvoiceSnapshot(
      invoiceId: data['invoice_id'] as String,
      invoiceNumber: data['invoice_number'] as String,
      finalizedAt: DateTime.parse(data['issued_at'] as String),
      companyName: companyLegalName,
      currency: data['currency'] as String,
      paymentStatus: data['payment_status'] as String,
      totalMinor: data['total_minor'] as int,
      lines: lines,
      isFinalized: false,
    );
  }
}
