# Upgrade 464 — Credit Authorization Readiness Diagnostics

Added an employee-facing **Check Authorization Readiness** button in the invoice authorization dialog and a permission-controlled, read-only Supabase RPC `gs_staff_credit_authorization_readiness(review_id)` returning authorization request statuses, independently verified binding flag, historical safety-hold flag, and an explicit **eligible_for_consent=false** status. It never activates an identity, records consent, approves credit, or debits an account.

## Deployment
Apply migration 464 after 463. This migration has not been run against a live Supabase instance. Flutter compilation and end-to-end tests are pending. Section 04 progress remains **91% estimated**.
