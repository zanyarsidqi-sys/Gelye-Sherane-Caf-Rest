# Upgrade 1139 — Kitchen handover integrity

Section 05 / Live Kitchen Orders: before marking an order served, fetch the latest order items and refuse handover if no items exist or product identifiers, quantities, IQD amounts, or quantity-times-unit-price totals are invalid. Recheck employee identity and queue generation after the asynchronous fetch. Keep existing SQL RPC as the authoritative status transition; this is an additional client-side guard, not a replacement for server-side checks.

Validation: static regression tests and ZIP integrity only. Flutter compilation and live Supabase tests not performed.
