# Upgrade 136 — Mixed-payment checkout preflight

Introduces a visit-wide **read-only** RPC that reports whether every
noncancelled order has a cash-only or mixed-payment finance attestation,
whether cancelled orders contain financial evidence, and whether guest
departure/cleaning/shisha physical checkout requirements are complete.
Also detects conflicting open visits and requires an occupied table.

Returns a specific blocking reason and `eligible_for_future_release` for
a mixed-payment visit. This is a snapshot for staff review, **not an
authorization to close the table**: the future release function must
recheck under row locks to prevent concurrent changes.

No existing cash-only release logic is modified. Mixed-payment release
remains disabled. Provider webhook/API integration and live deployment,
schema compatibility, Flutter compilation and race testing remain pending.
