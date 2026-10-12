# Dashboard Upgrade 100 — Finance Review of Cash Corrections

Added draft backend support for reviewing the pending cash receipt correction
requests introduced in Upgrade 99.

- Trusted administrators must provision eligible finance reviewers; no
  employee self-enrollment is available.
- Reviewer must have an authenticated MFA AAL2 session.
- The original requester cannot review their own correction.
- The request and receipt are locked/read and their order and amount checked.
- A single immutable review records decision, reviewer, amount snapshot,
  explanation, and timestamp; a protected audit event is written.
- Rejection changes the request to rejected with resolution metadata.
- Approval records `approved_for_posting` but **does not post** a correction,
  modify receipts, alter settlement, or release tables.

## Outstanding work
AAL2 is not fresh step-up authentication. Verify finance reviewer provisioning,
implement a trustworthy adjustment posting/reversal process, reconcile against
all payment methods, and test concurrency, migrations, Flutter UI, and RLS.

Verification: ZIP CRC and duplicate-entry checks only. No SQL execution or
Flutter compilation performed.
