# Upgrade 415 — Credit Account Link Approval Readiness

Adds a server-side permission-gated, read-only link approval readiness check. Validates the pending link state, compares barcode registry and account references, and confirms whether an independent employee has reviewed submitted evidence. Explicitly flags missing authoritative identity verification and customer consent, and always returns approval blocked. Credit Identity Evidence Review now has a **Link Readiness** button for each review.

No customer, link or account status changes; no limits, balance modifications, or debits. Apply `20261010_415_credit_link_approval_readiness.sql` in migration order. Flutter compilation and live Supabase tests not performed.
