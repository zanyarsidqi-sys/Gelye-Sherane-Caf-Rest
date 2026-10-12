# Upgrade 460 — Credit Authorization Historical Identity Hold Guard

Adds a database trigger that rejects credit authorization requests when the linked credit customer has any historical identity safety hold. This prevents a new authorization request from bypassing an unresolved customer dispute. Also adds a permission-gated, minimal-data staff diagnostic RPC.

No customer identity verification, consent, credit deduction, or settlement is enabled. Historical holds remain restrictive until a separately audited dispute-resolution workflow exists.

Verification: ZIP integrity only. Flutter build and live Supabase migration not tested.
