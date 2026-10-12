# Upgrade 419 — Identity Approval Eligibility Gate

Adds an employee **Approval Eligibility** action on each identity evidence review, backed by a read-only, permission-controlled RPC. Checks that the review still matches the linked account, link and account are pending, registry references match, and a different employee reviewed evidence. It explicitly reports that authoritative identity verification and customer consent are unavailable and **always blocks activation**. It does not change any balances, credit limits, identity status or payment state.

Apply migration `20261010_419_credit_identity_review_eligibility.sql`. Flutter and live Supabase migration were not tested.
