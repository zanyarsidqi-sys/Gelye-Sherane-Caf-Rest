# Upgrade 470 — Table Orders refresh correctness and cross-section review

- Fixed two real staff UI refresh races: employee service-job queue and per-item fulfillment board previously discarded a refresh when an earlier request was loading. They now queue and execute a follow-up refresh, avoiding stale statuses after overlapping actions.
- Extended the static section audit with a critical cross-section integration RPC reference inventory, including SQL declaration checks. See `reports/section_review_470.json`.
- No database migration or payment behavior changed. Existing credit settlement remains disabled.
- Static source inspection only; Flutter compile, Supabase migrations, and live end-to-end workflows remain unverified.
- Progress: Dashboard unassessed; Tables 94% historical estimate; Table Orders 69% historical estimate; Motel Orders 91% estimate. None verified complete.
