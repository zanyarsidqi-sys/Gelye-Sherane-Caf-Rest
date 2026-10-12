# Upgrade 309 — Secure customer QR bill navigation

The QR customer menu now shows **Check table bill** as an actionable entry only after `gs_customer_visit_session_valid` returns true. It opens the existing `CustomerTableBillScreen` with the staff-issued visit session token, not the public static QR token. The screen calls `gs_customer_visit_bill_preview` to show item quantities and gross ordered IQD amounts. This is **not** the payable balance, does not expose payments, and does not authorize transactions. A revoked or expired visit token is rejected again by the server-side RPC.

The menu now explains that bill preview is available for verified visits while direct ordering remains disabled. No schema migration is required for this change.

**Not verified:** Flutter compilation and Supabase live testing; SQL bill function schema compatibility and customer access flow still require testing.
