# Upgrade 1372: cash receipt count filter

Adds a second filter to the authorized Dashboard cash reconciliation list using the existing `cash_payment_count` RPC field. Options distinguish positive, zero, and unavailable counts without inventing settlement state. Combines with recorded cash filter; bottom-of-list cash total sums exactly displayed rows. Existing finance attestation, RPCs, and read-only detail access remain unchanged. No invoice print/save actions added.

Validation: ZIP CRC, original file preservation, static source assertions. Flutter compile and live Supabase/RLS verification pending.
