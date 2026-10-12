# Upgrade 1236 — Static station printing safety review

Changes:
1. Hardened StationTicketFormatter: strips control characters and embedded newlines from untrusted product/customer/note fields, reducing printer-command and forged-line injection risk.
2. Hardened StationPrintWorker: when an exception occurs AFTER claiming a ticket (resolver, formatting, adapter, or acknowledgment), the local ticket is marked uncertain and the error callback is invoked. The server already holds claimed tickets in UNKNOWN, so no automatic retry is scheduled.
3. Hardened revision request idempotency: a repeated request key must match original ticket, kind, reason AND normalized order item IDs/quantities. Different contents under the same key are rejected.

Review findings and outstanding work:
- Static source inspection only; no compiler, Supabase deployment, physical printer, or end-to-end testing.
- Server UNKNOWN tickets require an owner-authorized manual review and recovery workflow; an in-memory uncertainty set is not durable.
- Printer adapter still needs hardware-specific implementation and verifiable status semantics.
- Check SQL table and column compatibility and service-role/SECURITY DEFINER boundaries against a live database before deployment.
- The POS lifecycle, staff authorization and screen-level status must be exercised in integration tests.
- A4 official invoice PDF and official compliance verification remain future work.
- Shared application/footer and receipt branding need cross-platform visual testing.

Do not treat 97% planning estimate as tested readiness.
