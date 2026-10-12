# Upgrade 452 — Historical Customer Safety Hold Enforcement

Prevents employees from bypassing a disputed identity onboarding request by cancelling it and creating a new onboarding request for the same customer or authenticated user. Database trigger enforces the hold on new and reassigned requests; staff-only read-only diagnostic reports whether a hold exists without revealing sensitive dispute notes. Historical holds are intentionally not removable via employee APIs.

This is a security hardening increment, not customer identity verification or credit payment implementation. Flutter build and live Supabase migration tests have not been run.
