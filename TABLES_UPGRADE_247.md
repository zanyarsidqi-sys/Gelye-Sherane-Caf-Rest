# Upgrade 247 — Payment source audit and reconciliation contract repair

- Fixed gs_prepare_locked_discount_payment to recognize the actual `provisional_no_known_payment` eligibility value returned by the upgrade-242 reconciliation function.
- Added extra guards ensuring reconciliation is explicitly read-only and does not authorize settlement.
- Added admin-only gs_locked_discount_payment_source_audit(order_id) for inspecting payment table existence, schema columns, invoice snapshot and prepared intent, without changing balances.
- Audit schema inspection does not certify external payments or migration completeness.
- Physical printing, cash/credit capture and live Flutter/Supabase tests remain pending.
