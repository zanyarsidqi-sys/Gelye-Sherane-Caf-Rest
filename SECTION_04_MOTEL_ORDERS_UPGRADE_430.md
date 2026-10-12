# Upgrade 430 — Safe Re-request After Cancellation or Expiry

**Fixed a database contradiction:** Upgrade 421 created a permanent unique index for `(review_id, invoice_reference, amount_iqd)`, preventing new requests even after cancellation or expiry. Upgrade 429 intended to permit retries but its trigger could not override that index. This migration replaces the unique index with a nonunique history index and updates the creation RPC to rely on Upgrade 429’s invoice-wide, transaction-locked live-request guard. Previous requests and audit history are preserved.

**Behavior:** One unexpired, outstanding authorization request per invoice; cancelled or expired requests no longer permanently block a new request. The invoice must still exist, be unpaid, and match the amount. No customer consent or credit debit is enabled.

**Verification:** ZIP structure only; Flutter compilation and live Supabase migration were not tested. Migration must run after Upgrade 429.
