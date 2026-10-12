# Upgrade 457 — Customer-owned identity hold status

Adds an authenticated, ownership-checked read-only RPC for the status of an individual onboarding safety hold, and a **Hold Status** button on each customer onboarding request. A customer can inspect their own hold reason and timestamp, but cannot inspect another customer’s request. Missing or failed checks never indicate authorization.

This does not verify identity, record payment consent, or enable credit deductions. Flutter compilation and live Supabase migration testing have not been performed.
