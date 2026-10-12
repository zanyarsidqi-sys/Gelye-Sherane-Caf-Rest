# Upgrade 1198 — Wrong/Waste Order Corrections (foundation)

Implemented: correction request and approval records, reasons, quantity checks,
actor/time audit, optional replacement product reference, and permission-gated RPCs.
No source order items are deleted.

IMPORTANT: Approval DOES NOT YET change the payable balance, invoice, payment,
credit, stock, or preparation tickets. The existing financial queries use raw
line_total_iqd sums. Do not present approved corrections as removed charges.

Next steps: a single authoritative net-bill calculation across every financial
path; approved-quantity adjustment with concurrency locking; replacement item
creation with server-side mode pricing and zero-charge manager authorization;
settled invoice refund/credit path; inventory waste movement; station notification;
end-to-end regression checks before production deployment.
