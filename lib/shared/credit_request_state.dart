/// UI-facing credit withdrawal states. These are NOT proof of payment.
enum CreditRequestStatus {
  draft,
  pendingApproval,
  approved,
  posted,
  rejected,
  cancelled,
  reversed,
}

/// Valid state transitions for a future server-authoritative ledger.
/// The server must independently enforce these rules and role permissions.
class CreditRequestState {
  static bool canTransition(CreditRequestStatus from, CreditRequestStatus to) {
    switch (from) {
      case CreditRequestStatus.draft:
        return to == CreditRequestStatus.pendingApproval ||
            to == CreditRequestStatus.cancelled;
      case CreditRequestStatus.pendingApproval:
        return to == CreditRequestStatus.approved ||
            to == CreditRequestStatus.rejected ||
            to == CreditRequestStatus.cancelled;
      case CreditRequestStatus.approved:
        return to == CreditRequestStatus.posted ||
            to == CreditRequestStatus.cancelled;
      case CreditRequestStatus.posted:
        return to == CreditRequestStatus.reversed;
      case CreditRequestStatus.rejected:
      case CreditRequestStatus.cancelled:
      case CreditRequestStatus.reversed:
        return false;
    }
  }

  static bool isSettled(CreditRequestStatus status) =>
      status == CreditRequestStatus.posted;
}
