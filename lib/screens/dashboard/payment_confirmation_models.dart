/// Client-side payment review types. The server is the sole authority for
/// confirming receipt, debiting credit accounts, and settling invoices.
enum PaymentReviewStatus { pending, approved, rejected }

enum PaymentReviewMethod { credit, online }

class PaymentReviewRecord {
  const PaymentReviewRecord({
    required this.id,
    required this.orderId,
    required this.amountIqd,
    required this.method,
    required this.status,
    this.transactionReference,
    this.evidencePath,
    this.submittedBy,
  });

  final String id;
  final String orderId;
  final int amountIqd;
  final PaymentReviewMethod method;
  final PaymentReviewStatus status;
  final String? transactionReference;
  final String? evidencePath;
  final String? submittedBy;

  static PaymentReviewRecord fromJson(Map<String, dynamic> json) {
    final amount = json['amount_iqd'];
    if (amount is! num || amount < 0 || amount.toInt() != amount) {
      throw const FormatException('Invalid payment amount');
    }
    final id = (json['id'] ?? '').toString();
    final orderId = (json['order_id'] ?? '').toString();
    if (id.isEmpty || orderId.isEmpty) {
      throw const FormatException('Missing payment or order ID');
    }
    final rawMethod = (json['method'] ?? '').toString().toLowerCase();
    final method = switch (rawMethod) {
      'credit' => PaymentReviewMethod.credit,
      'online' || 'zaincash' || 'fastpay' || 'qi' || 'bank_transfer' => PaymentReviewMethod.online,
      _ => throw const FormatException('Unsupported payment method'),
    };
    final rawStatus = (json['status'] ?? 'pending').toString().toLowerCase();
    final status = switch (rawStatus) {
      'pending' || 'pending_confirmation' => PaymentReviewStatus.pending,
      'approved' || 'confirmed' => PaymentReviewStatus.approved,
      'rejected' => PaymentReviewStatus.rejected,
      _ => throw const FormatException('Unsupported payment status'),
    };
    return PaymentReviewRecord(
      id: id, orderId: orderId, amountIqd: amount.toInt(),
      method: method, status: status,
      transactionReference: json['transaction_reference']?.toString(),
      evidencePath: (json['evidence_path'] ?? json['screenshot_path'])?.toString(),
      submittedBy: json['submitted_by']?.toString(),
    );
  }

  bool get requiresReceiverVerification => status == PaymentReviewStatus.pending;
}
