# Phase 3 — Public request validation (source update)

Implemented a SQL migration (`supabase/migrations/20261009_011_public_request_validation.sql`) adding transaction-safe, per-normalized-phone hourly submission limits (3 requests per hour per kind), stronger phone validation, safe numeric JSON checks, server-side menu pricing, and atomic request creation. Existing UI and 35 sections remain intact.

**Not yet production ready.** This is defense-in-depth, NOT IP/device rate limiting or CAPTCHA. An attacker can vary phone numbers. Add an edge gateway with IP/device throttling, CAPTCHA verification, monitoring, and deployment testing before enabling public anonymous requests. Migration is not applied to the live database; Flutter build and integration tests were not run.

**Progress:** Historical Phase 3 estimate 54% (unverified); no numerical increase. 35 section-level verifications remain; additional implementation and integration work remains.
