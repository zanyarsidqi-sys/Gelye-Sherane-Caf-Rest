# Upgrade 101 — Cash correction posting preflight

Added a read-only, permission-checked diagnostic for cash correction requests.
It compares the original receipt/order, finance decision, reviewer, immutable
adjustment snapshot, existing cash-ledger links and competing requests.

**No correction is posted.** `posting_authorized` is always `false` because
verified, serialized accounting adjustments and refund/provider confirmation
are not implemented. A finance review is not proof that cash was returned.

Next: implement a trusted posting workflow with exact-once identifiers,
serialized order-level locks, full correction/refund accounting, and
independent finance approval before allowing customer balances to change.

Static source and ZIP checks only; no Supabase migration run or Flutter build.
