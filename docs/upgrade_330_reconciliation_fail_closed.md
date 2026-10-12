# Upgrade 330 — Fail-closed reconciliation diagnostics

The staff reconciliation screen now validates every required integer amount, the requested order ID, exception count, warning, and the server settlement/transfer flags before rendering financial values. Unexpected or incomplete responses are hidden and shown as a verification-required error. A visible blocked settlement/transfer indicator reinforces that the RPC is diagnostic only.

No payment records are mutated. No customer-facing payable balance is introduced. Live Supabase and Flutter compile tests remain outstanding.
