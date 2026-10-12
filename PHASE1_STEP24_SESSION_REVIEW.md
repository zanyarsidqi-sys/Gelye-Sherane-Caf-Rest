# Phase 1 Step 24 — Fail-closed session startup

- startup_catches_supabase_init: True
- saved_session_rechecks_identity: True
- saved_session_requires_dashboard: True
- saved_session_rechecks_mfa: True
- app_rechecks_restoration: True
- app_fails_closed: True

Source checks only; compile, MFA, RLS and live session-revocation behavior require integration testing.
