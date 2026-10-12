# Upgrade 580 — Recovery UI race protection

## Scope
Section 03 Table Orders; preserves all existing management sections and migrations.

## Fixes
- Recheck employee identity and widget lifetime after asynchronous local recovery record deletion. Prevents showing another employee a stale completion notification or clearing their pending recovery UI.
- Check that the pending request ID still matches before clearing the UI, preventing an older response from clearing a newer recovery pointer.
- Refresh the order board after a server-confirmed replacement, including when confirmation comes from durable receipt recovery.

## Verification
Static regression assertions cover the three changed completion paths. Flutter compilation, live Supabase transactions, and actual employee-switching runtime behavior remain unverified.
