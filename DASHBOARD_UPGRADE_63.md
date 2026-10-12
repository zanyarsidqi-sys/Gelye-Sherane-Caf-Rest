# Dashboard Upgrade 63 — Transfer financial preflight (draft)

Added `20261009_063_transfer_financial_preflight_draft.sql`:

- Permission-gated, read-only breakdown of selected items and their original
  unit prices, requested quantity and transfer value.
- Compares source order total, recorded cash, verified external evidence,
  owner offers and overlapping transfer requests.
- Reports explicit blocking reasons, including changed quantities and
  mismatched visit identity.
- `ready_to_apply` is deliberately always FALSE. No money or items move.
- Revokes authenticated execution of the **legacy** `gs_transfer_cafe_table`
  function because it changes order destinations without respecting visits.
  This is a breaking change: a replacement workflow is required before deploy.

**Still outstanding:** authoritative unified payment ledger and provider
verification; atomic split/transfer execution; concurrent checkout locking;
customer movement and destination capacity; approvals and full audit;
Flutter integration; migration testing and production rollout plan.

No live Supabase deployment or Flutter compilation was performed.
