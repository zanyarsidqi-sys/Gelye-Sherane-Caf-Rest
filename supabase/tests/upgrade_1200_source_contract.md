# Upgrade 1200 source review checklist (live tests deferred)
- Corrected invoice quote excludes approved removed quantities only.
- Pending corrections block corrected cash capture.
- Cash collection locks the parent order, enforces remaining balance, and is idempotent by reference.
- Existing discount snapshots, unified ledger entries, motel orders, and attestations block this cash writer.
- Replacement is inserted at current server price once, under the order lock; original order line remains auditable.
- Legacy ledger writes remain blocked for corrected orders.
- **Deployment warning:** Other legacy invoice display, card, credit, mixed, refund, inventory, and offline writers are NOT integrated. Verify database migrations, triggers, all writer paths, and full checkout on a staging Supabase project before production.
