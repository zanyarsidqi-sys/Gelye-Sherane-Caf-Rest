# Upgrade 577 — Exact-match pending replacement recovery

## Change
The Table Orders cross-device/manual receipt lookup now resolves a locally
pending replacement only if the server reports a committed receipt for the
same request UUID, order item, replacement product, and IQD difference.
After a verified match, the local recovery pointer is cleared and the order
board is refreshed. Unrelated receipts, incomplete receipts, and mismatches
cannot clear the pending pointer. No mutation is replayed.

## Verification
Static regression tests are included in
`tests/integration/test_upgrade_577_pending_lookup.py`.
Flutter compilation and live Supabase transaction testing remain outstanding.

## Sections 01–07
This upgrade improves Section 03. It does not certify Sections 01–07 as
complete. A combined integration and runtime verification pass is required.
