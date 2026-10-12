# Upgrade 1408: linked financial workflow review

## Implemented
- Pending Payment per-invoice settlement evidence fails closed when the authorized allocation diagnostics response reaches its 200-record cap.
- Existing server-authorized Standing Cash cash collection and Pending Payment read-only behavior retained.

## Linked sections inspected for required future integration
- Table Orders: source order identity, partial settlement and table occupancy.
- Motel Orders: prepaid package, charge identity, and invoice posting.
- Online Orders: verified source classification is not yet established for Pending Payment.
- Credit Management: credit request is not cash receipt; debit finality must be verified.
- Cash Reconciliation: separate cash-only evidence; not all-method due.
- Financial Overview and Dashboard: avoid totals from capped or non-authoritative samples.

## Blocked pending verified backend contracts
- Authenticated cursor pagination and exhaustive source coverage.
- Verified per-source all-method paid/outstanding and prepaid allocation.
- Secure full/partial/mixed collection for Pending Payment.
- Flutter build, live Supabase authorization and end-to-end settlement tests.

No migrations or collection permissions were changed.
