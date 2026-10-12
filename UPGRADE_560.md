# Upgrade 560 — Quote quantity binding

The final replacement RPC now requires the quantity seen during quotation and compares it to the current order item under locks before invoking the existing financial/kitchen guarded replacement. The six-argument RPC is revoked from authenticated callers; the seven-argument wrapper retains permission checks. Existing records and migrations are preserved.

Static tests only; Flutter compilation and live Supabase execution are not verified.
