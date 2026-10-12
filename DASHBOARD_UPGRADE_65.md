# Dashboard Upgrade 65 — Order Financial Integrity Guard (DRAFT)

Added a database trigger to block silent modification or deletion of order
items after any cash payment, external payment evidence, pending/verified
owner complimentary offer, or active bill-transfer request exists.

- Protects original product, unit price and quantity snapshots.
- Serializes item updates with cash collection via the order-row lock.
- Rejects reassigning an item to a different order (prevents rewriting history).
- Does NOT transfer bills, approve payments, move customers or settle orders.
- Requires an audited correction/refund workflow before deployment.

**Estimated remaining coding roadmap after 65: 8 stages (66–73)**:
66 provider/credit verification; 67 unified ledger; 68 transfer execution;
69 join/move guests and capacity; 70 owner MFA approvals;
71 motel meal barcode/settlement; 72 offline and notification integration;
73 Dashboard review and Flutter/Supabase test preparation.

This is a planning estimate, not a guaranteed finish. Live integration,
compilation, data migrations and fixes may add more stages. No production
verification has been performed.
