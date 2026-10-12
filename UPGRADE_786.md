# Upgrade 786 — table movement review

Section: tables

Acceptance checkpoint: verify `gs_request_table_guest_move` in `lib/sections/tables.dart`.

Result: PASS in static source inspection. This does not establish Flutter runtime behavior, Supabase security, or production readiness.

No application code change for this checkpoint; it is a newly recorded acceptance assertion.
