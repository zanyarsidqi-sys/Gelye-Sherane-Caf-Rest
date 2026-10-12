# Upgrade 400 — Motel Cash Settlement Report

Adds a permission-gated read-only RPC for the latest 100 (maximum 500) cash settlements, including receipt reference, employee, timestamp, amount and reconciliation status. Checks invoice paid status, amount, payment draft, and receipt acknowledgement. Adds a Cash Settlement Report action in the employee finance handoff screen and updates descriptions to distinguish cash settlements from unprocessed credit/electronic drafts.

**Limitations:** Reports only UUID-native motel-food cash ledger; no shared numeric-order accounting integration, refund/reversal or credit/electronic settlement. No Flutter compile or live Supabase migration tests performed. Investigate any reconciliation mismatch before production use.
