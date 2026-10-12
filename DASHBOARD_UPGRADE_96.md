# Dashboard Upgrade 96 — Legacy table release bypass closed

The earlier `gs_update_cafe_table` RPC allowed an employee to set
`occupied=false` after kitchen orders were completed, without verified
financial settlement or cleaning. This upgrade **replaces that RPC** with a
fail-closed version that rejects all attempts to release a table through it.

It also refuses to occupy an empty table (use the dedicated visit-opening RPC),
requires an active visit for occupied-table edits, checks capacity and
cleaning/departure state, and blocks tourism-mode changes after noncancelled
orders exist for the visit. Authorized guest-count updates remain possible.

**Compatibility caution:** Older Flutter callers using the legacy RPC to
release tables will now receive a deliberate error. A complete release RPC
is still needed. This is a security safeguard, not a working checkout.

**Verification:** ZIP CRC and source inclusion only. Supabase migration,
Flutter compilation and device testing have not been performed.
