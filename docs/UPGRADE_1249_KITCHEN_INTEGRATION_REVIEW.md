# Upgrade 1249 — Kitchen integration and security review

## Implemented
- Revoke direct anon/authenticated execution of the three station revision-print device RPC families. These must be called only through the server-side Edge Function with a verified station session token.
- Revalidate active station-specific supervisor membership when a print-review idempotency request key is replayed. Previously a removed supervisor could receive `already_reviewed` metadata for an earlier review.
- Add input validation to both POS and A4 invoice template entrypoints. Printing remains read-only and cannot charge customers.

## Source findings and remaining gaps
- `station_print_worker.dart` correctly retains uncertain tickets without automatic retry. Physical printer confirmation is adapter-specific and unverified.
- Station original/revision print claims must be tested against revoked tokens and wrong-station access in staging.
- `GelyeInvoicePrintBoundary.requireFinalized` requires an authoritative finalized invoice identity from Finance; the actual finance retrieval/renderer wiring is unfinished. `a4Document` returns structured data, not a PDF.
- Kitchen order customer/station labels and product routing must be verified on running devices; no live verification performed.
- The source migration replaces the review function without altering prior immutable audit records. Deploy migrations sequentially and test rollback/permission behavior in staging.
- Existing historical revision SQL functions may contain other issues; this is not a complete security audit.

## Deferred by request
Flutter compilation, Supabase execution/authorization tests, hardware printer testing, and PDF/physical invoice printing.
