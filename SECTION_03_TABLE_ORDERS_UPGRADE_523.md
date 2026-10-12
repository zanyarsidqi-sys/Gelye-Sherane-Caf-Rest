# Upgrade 523 — Confirm and verify quantity corrections

- Before any quantity correction changes a table order, staff must review product, table, old/new quantity and unit difference in a second confirmation dialog.
- Cancellation does not invoke the write RPC.
- Financial totals are intentionally not calculated by Flutter: Supabase uses the persisted unit price in the existing Upgrade 522 transactional RPC.
- After confirmation, the UI rechecks board freshness and item status, and validates the quantity returned by Supabase. Unexpected results are treated as errors, followed by a board refresh.
- Existing employee permissions, kitchen ticket protections, invoice protections, and audit revision dispatch remain enforced by the server.
- No new Supabase migration; Upgrade 522 migration is still required.
- Flutter compilation and live Supabase testing remain outstanding.
