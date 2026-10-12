# Dashboard Upgrade 71 — Motel Meal Detail & Verification Diagnostics

Added read-only `gs_dashboard_motel_meal_offer_detail(offer_id)` with:
- Employee permissions for Dashboard and Motel Orders.
- Reservation identifier and verification flag, without exposing QR secrets.
- Item quantities, included quantities, tourism price snapshots and totals.
- Explicit missing-reservation, missing-items, and payment/entitlement warnings.
- Scheduled delivery time and fulfillment status.

**Not yet implemented:** scanning/resolving motel reservation barcodes,
trusted reservation API connection, server-enforced tourism price on order
creation, reception entitlement checks, actual prepaid/credit ledger posting,
kitchen scheduling, delivery actions and offline behavior. A verification
flag stored in a table is not independently proof of external verification.

No write permissions or booking/payment confirmation endpoint are added.
This draft is not deployable without schema reconciliation and tests.
