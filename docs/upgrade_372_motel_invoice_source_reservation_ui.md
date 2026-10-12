# Upgrade 372 — Employee invoice source reservation action

Added an employee-facing action to reserve approved, verified motel food source references using the existing Upgrade 371 transactional RPC.

- Accessible through the invoice draft row action menu.
- Only offered for unblocked, currently reviewed drafts.
- Requires explicit employee confirmation and displays the count and IQD total returned by the server.
- Server enforces both motel_orders and invoices_payments edit permissions, guest stay, approval fingerprint and uniqueness.
- A stale or conflicting reservation returns an error; no silent relinking.
- This is NOT an official invoice, a payment, or a credit deduction.

Verification: ZIP integrity and path uniqueness checked. Flutter CLI and live Supabase unavailable; migration and UI remain untested at runtime.
