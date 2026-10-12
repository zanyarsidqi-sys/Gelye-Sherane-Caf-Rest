# Upgrade 425 — Time-Bound Credit Authorization Requests

Added a 24-hour expiry timestamp to customer credit authorization requests, including backfill for earlier records and a database trigger to prevent expiry changes. Staff can inspect the expiry status with a new **Expiry Check** action. The RPC also states that customer authentication and consent remain unverified and credit payment remains blocked.

This is **not** customer-facing consent confirmation. Expiry does not automatically change request status or permit settlement; later customer-authentication and consent workflows must independently enforce expiry. No credit account balance or payment is changed.

Migration: `20261010_425_credit_authorization_expiration.sql`. Flutter compilation and live Supabase tests not performed.
