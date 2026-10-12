# Upgrade 468 — cross-section review and iPhone tab navigation fix

## Actual change
- Fixed a narrow-screen usability risk in Table Orders: seven tabs now use a horizontally scrollable TabBar rather than attempting to fit all labels into an iPhone-width row.
- Added `tools/section_review.py`, a reproducible **read-only static audit** for Dashboard, Tables, Table Orders, Motel Orders, migration file count, and test file inventory.
- Preserved all earlier files, Supabase migration history and credit-payment fail-closed safeguards.

## Progress based on latest explicitly recorded section checkpoints
- Section 01 Dashboard: **percentage not reliably established**; 81-step planning milestone is not functional completion. Dashboard access and live metrics still need verification.
- Section 02 Tables: **94% estimated coding progress** in latest Tables upgrade notes; unverified.
- Section 03 Table Orders: **69% historical estimate** from prior Section 04 notes; potentially stale, requires re-baselining; unverified.
- Section 04 Motel Orders: **91% estimated coding progress**; unverified.

## Acceptance gates
- Flutter SDK: run `flutter pub get`, `flutter analyze`, `flutter test`, and iPhone/Windows/web UI checks.
- Supabase: apply migrations in a disposable environment; check RLS, auth, permission and race-condition behavior.
- Cross-section: Dashboard -> Tables -> Table Orders -> Motel Orders navigation, tourism pricing, cancellations, invoices and finance reconciliation.
- Credit: authoritative identity, authenticated consent, balance/limits and idempotent journal before enabling deductions.

No section is 100% verified. The audit script is a static inventory and is not a substitute for integration testing.
