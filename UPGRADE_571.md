# Upgrade 571 — Replacement reconciliation guidance

Added read-only, permission-inheriting classification of replacement receipt evidence. States: unconfirmed, revision_investigation, dispatch_investigation, item_changed_since_receipt, recorded_evidence_consistent. The staff lookup displays a recommended next step and does not imply that payment or kitchen acknowledgment was verified. Requires migration 570. No automatic retry or financial mutations.

Verification: static tests only; no live Supabase, Flutter build, or end-to-end testing.
