# Upgrade 142 — Database compatibility preflight

Introduces a fail-fast, read-only SQL migration to check that critical
tables/columns and checkout functions required by the mixed-payment
workflow exist with expected names. It also refuses to proceed if the
mixed checkout feature gate has been enabled prematurely.

This is a **static schema presence check**, not a proof of correct column
types, trigger behavior, RLS, concurrency safety or provider authenticity.
It must be run against staging. A failure should be investigated and
repaired with an additive migration, not bypassed.

Mixed-payment release remains disabled; no provider API credentials or
live runtime access were available. ZIP integrity only was verified.
