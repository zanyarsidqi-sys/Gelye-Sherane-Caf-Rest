# Upgrade 432 — Pending Credit Identity Onboarding

Adds an employee-initiated, permission-gated pending identity onboarding request that connects an existing credit customer ID with an existing Supabase auth user ID. The backend validates both IDs, prevents duplicate pending requests and conflicts with existing verified bindings, and records who requested the onboarding and why. An authenticated customer can inspect only their own pending request using `gs_credit_my_pending_identity_onboarding`.

**Not identity verification:** Neither an employee request nor customer login proves ownership of a credit account. There is no approval/verification RPC, no customer consent and no credit debit. A separately designed identity proofing workflow is required before activating these.

Migration: `20261010_432_credit_identity_onboarding_requests.sql`. Flutter and live Supabase testing not performed.
