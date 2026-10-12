# Phase 3 — Pay Now (read-only checkout preparation)

- Pay Now now shows authorized order review and calculated order values, with a checkout preparation notice.
- Cash, card, and credit are explicitly marked **not connected**; no payment is created.
- Reuses existing `InvoiceReviewPanel` Supabase read-only query and existing SectionShell authorization.
- No database migrations, writes, settlement claims, or authentication changes.
- **Not implemented:** payment collection, partial/split payments, refunds, invoices, receipts, reconciliation, or backend idempotency.
- Flutter compilation and live Supabase/RLS tests are pending.
