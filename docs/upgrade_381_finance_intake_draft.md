# Upgrade 381 — Finance intake draft

- Added `gs_motel_food_unified_invoice_intake` as an **isolated draft intake** for the future unified invoice system.
- Creation requires valid finance attestation and current source readiness, checked server-side under an invoice-register row lock.
- Unique constraints enforce one draft per food invoice, guest stay and finance attestation; repeated calls return the same draft if unchanged.
- New employee button creates the intake draft after confirmation. Failed/stale attestation blocks creation.
- **Not** an official invoice, payment, accommodation bill, or credit deduction. No writes to legacy financial ledger.
- Flutter compilation and live Supabase migration have not been tested. Apply migrations sequentially in a test environment before production.
