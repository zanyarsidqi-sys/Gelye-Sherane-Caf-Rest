# Dashboard Upgrade 56 — Motel meal scheduling and join-table foundation

- Motel meal offers now have fields for verified reservation identity, verified
  payment, delivery timestamp and receptionist actor (all unpopulated until
  secure integration is built).
- Structured meal items include quantities, tourism-mode price snapshots and
  package-included quantities, separate from free-form meal summaries.
- Added a locked-down transfer request schema for joining tables and moving
  selected unpaid items between active table visits.
- The transfer schema stores requests only: it does NOT transfer a bill, change
  payment allocation, move guests or edit order items. No staff write grants.

NOT IMPLEMENTED: barcode generation/scan, reservation validation, motel
entitlement and payment verification, reception creation UI, kitchen scheduling,
secure bill-transfer execution, partial split, capacity checks or audit writers.
Draft migration; never deploy without reconciling existing table/order schema.
Flutter compilation and Supabase live tests remain deferred.
