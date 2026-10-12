# Upgrade 1382: Standing Cash and Pending Payment card detail alignment

- Standing Cash detail displays the authorized cash-only sample order count and clarifies which orders can open server-gated cash collection.
- Pending Payment detail displays the posted motel invoice sample count and explicitly states that collection remains disabled.
- Existing payment RPCs, idempotent reference, authorization, cash-only limits, and pending settlement restrictions remain unchanged.
- Source-based preview must not imply verified all-method balances or mixed payments.
- Validation: ZIP CRC, original archive entry preservation and exact source assertions; no Flutter compile, runtime screenshot or live Supabase verification.
