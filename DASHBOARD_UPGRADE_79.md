# Dashboard Upgrade 79 — Motel reservation QR locator foundation

Added a protected database table of SHA-256 QR token digests, with expiration
and revocation fields, plus a permission-gated lookup RPC.

**Security boundary:** the QR only locates a reservation. It does NOT prove
who the guest is, that the reservation is active, that meals are included,
that payment was received, or that a delivery is permitted. It does not
change `reservation_verified_at`, `payment_verified_at`, or any balances.

Provisioning requires a trusted motel backend with cryptographically random
opaque tokens (at least 128 bits of entropy); never store or log raw tokens.
The motel backend must validate entitlement quantities and prevent reuse.

## Before production
- Confirm `extensions.digest` schema on the target Supabase instance.
- Verify staging SQL migrations and RLS/grants.
- Implement trusted reception reservation validation, entitlement and payment
  checks, secure token provisioning, rate limiting, and full audit logging.
- Integrate scanner in Flutter and test iPhone/Windows.

ZIP integrity checked; not compiled or deployed.
