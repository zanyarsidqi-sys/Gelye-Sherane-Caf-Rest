# Upgrade 573 — Complete kitchen dispatch reconciliation

Fixes a correctness gap in Upgrade 572: the generic kitchen reconciliation RPC only returned the most recent 250 dispatch rows for an order. The replacement-specific receipt check now reads **every** kitchen dispatch for the exact committed replacement revision, with per-dispatch audit consistency, duplicate audit detection, counts, and actionable staff guidance. Flutter's cross-device receipt lookup shows those totals. No automatic retries or kitchen dispatch mutations.

Apply migration 573 after 572. Static assertions are not substitutes for Flutter compilation, Supabase staging migration, RLS and real kitchen acknowledgment integration tests.
