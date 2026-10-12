# Phase 3 — Batch 10: Kitchen status workflow

- Kitchen live toggle now opens a live Supabase kitchen queue with server-controlled status actions.
- New optional SQL migration `20261009_002_kitchen_status.sql` implements transitions `new -> preparing -> ready -> served` and requires backend `kitchen.can_edit` permission.
- No direct table update policy is granted. Unauthorized and invalid transitions are rejected.
- The existing local preview remains available, and other screens are preserved.
- Database migration 001 must be reviewed/applied before 002. Neither migration has been applied to your Supabase project.
- Flutter compilation and real Windows/database tests have **not** been performed here.
- Estimated implementation progress 24%, **0/35 production-verified**. This estimate is not a test result.
