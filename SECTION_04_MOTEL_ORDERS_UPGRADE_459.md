# Upgrade 459 — Automatic Safety Hold on Customer Dispute

- Authenticated customer responses of `disputed` now create an irreversible identity safety hold in the **same database transaction**.
- Backfills historical disputed acknowledgements into the safety-hold table, preserving original response timestamps.
- Acknowledgements still fail if a hold exists; disputes do not verify identity or authorize credit.
- Customer UI explains that disputing creates a safety hold.
- Existing identity-review guards that consult the safety-hold table now also cover customer disputes submitted via the response workflow.

Migration: `20261010_459_customer_dispute_auto_safety_hold.sql`. Flutter build and live Supabase deployment not performed.
