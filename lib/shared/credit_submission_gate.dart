/// Safety checks for future server-side credit withdrawals.
/// This client-side model is informational only and cannot authorize payment.
class CreditSubmissionGate {
  static const requiredChecks = <String>[
    'Authenticated employee has credit-payment permission',
    'Customer barcode resolves to an active credit account',
    'Order exists and belongs to the selected order type',
    'Order amount and pricing mode verified by the server',
    'Available balance and credit limit verified by the server',
    'Approval policy resolved and any required approval granted',
    'Unique order payment key prevents duplicate posting',
    'Atomic ledger posting and audit logging are available',
  ];

  /// Do not allow a local UI to claim that server checks have passed.
  static bool canSubmitFromLocalDraft() => false;
}
