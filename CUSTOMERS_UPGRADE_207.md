# Upgrade 207 — Conservative customer spending ranking

Adds `gs_cafe_customer_verified_cash_spend()` and `gs_cafe_customer_cash_spend_history()` RPCs, plus a Top cash customers dialog in Section 08. Only immutable cash-only settlement attestations are included, matched through a uniquely customer-linked table visit and order. No inferred totals, unverified receipts, mixed, card, or credit. Counts and totals are **not** full customer lifetime spend; historical unattributed visits and payment corrections need future accounting review. Requires migrations through 206 and the existing cash-only attestation schema. Backend authorization requires `customers.can_view`.

ZIP integrity verified; Flutter compilation and live Supabase migration/testing not performed. Estimated Section 02 Tables 84%; Section 08 Customers 30%.
