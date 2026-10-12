# Upgrade 538 — Confirmed product replacement pricing

Section 03 — Table Orders. Adds a server-side replacement quote RPC, financial difference preview, and confirmed-price compare-and-swap on replacement commit. Quotes do not reserve prices. A changed price rejects the commit; staff must request a new quote. Kitchen revision dispatch is added to the existing revision outbox. Existing legacy five-argument replacement function is retained for migration compatibility but authenticated execution is revoked.

## Verification limitations
Static checks only; Flutter compilation and live Supabase migrations/RLS checks require configured SDK and database. Existing payment and station-ticket evidence continues to block replacement.
