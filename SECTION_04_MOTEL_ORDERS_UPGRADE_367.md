# Upgrade 367 — Official invoice integration safety review

Added a permission-protected, read-only architecture-check RPC and employee billing panel. It explicitly reports the existing invoice-link constraint, guest-stay scoping, payment allocation gap, and the limitation of count/total-only review freshness. No invoice or payment posting is enabled.

Next: harden draft review identity using order-level snapshots, then design verified official invoice posting against the actual finance schema.

Verification: ZIP integrity and unique paths only; Flutter compile and live Supabase migration not tested. Section 04 remains 72% estimated.
