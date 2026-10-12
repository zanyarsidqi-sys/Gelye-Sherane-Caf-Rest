# Upgrade 454 — Per-request Historical Safety Hold Check

Added an employee **Historical Hold Status** action on each onboarding request and a permission-controlled read-only Supabase RPC. It checks historical customer safety holds for both the credit customer and authenticated user, including holds on cancelled onboarding requests. Failure is displayed as blocked; it never grants identity approval, customer consent, or credit payment.

Migration: `20261010_454_credit_onboarding_request_hold_status.sql`. Flutter compilation and live Supabase migration were not performed.
