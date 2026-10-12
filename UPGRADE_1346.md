# Upgrade 1346 — Financial Overview & Payments

- Source-backed motel invoice settlement diagnostics: check invalid (zero/negative/null) cash settlement amounts.
- Correct requires_manual_review to include bridge amount mismatches as well as fingerprint collisions, bridge identity issues, invalid cash evidence and cash overage.
- Payments Management validates and displays invalid cash evidence and the manual-review state.
- Online order identity remains unverified; no new collection or total calculation is enabled.
- This migration replaces the existing read-only function and requires deployment/testing.
- Existing Standing Cash server-side collection is unchanged; production testing remains outstanding.
