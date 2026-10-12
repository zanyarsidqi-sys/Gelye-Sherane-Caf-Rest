# Phase 1 — Batch 37–40 (Rest)

Implemented:
- 37: Dashboard foreground preflight before network authorization.
- 38: Foreground recheck before granting dashboard access after async reads.
- 39: Revalidate session identity, epoch, and foreground after asynchronous favorites load before starting POS heartbeat.
- 40: Remove duplicate protected-route lock/generation increment in periodic verification.

All 7 source assertions passed. No Flutter/Dart SDK or live Supabase instance available, so compilation and runtime tests are pending. Existing migrations and other sources are unchanged.
