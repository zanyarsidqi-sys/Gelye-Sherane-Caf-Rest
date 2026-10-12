# Upgrade 1156 — Kitchen double-submit protection

Prevents rapid taps from opening multiple handover dialogs or starting parallel
status transitions for the same employee queue. The confirmation lock is
released on all exit paths (including cancelled dialogs and errors) and
cleared when the authenticated employee changes. Server-side status
transitions remain enforced by the Supabase RPC.

Verification: source regression tests only; Flutter compilation and Supabase
runtime acceptance are intentionally deferred until laptop testing.
