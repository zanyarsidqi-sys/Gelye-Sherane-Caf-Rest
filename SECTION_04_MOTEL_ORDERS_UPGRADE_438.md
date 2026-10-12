# Upgrade 438 — Independent Identity Approval Readiness

Added a permission-gated, read-only approval-readiness RPC and an **Approval Readiness** action in staff onboarding. It checks pending status, authenticated customer acknowledgement, independent evidence review, and existing verified-binding conflicts. Authoritative proof and final approval are explicitly marked unavailable; the RPC always reports identity approval blocked. No binding verification, customer credit consent, or debit is enabled.

Migration: `20261010_438_credit_identity_approval_readiness.sql`. Requires schema verification against the actual Supabase database; Flutter compilation and live migrations were not run.
