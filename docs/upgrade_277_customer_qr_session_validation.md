# Upgrade 277: Customer QR visit-session validation UI

- QR menu optionally accepts a staff-issued visit session token, separate from the public table QR token.
- Uses gs_customer_visit_session_valid to check session state; missing or failed checks fail closed.
- Shows an explicit verified/read-only status; no private order/bill data exposed.
- Refresh revalidates session and reloads current menu prices.
- No self-service session issuance, customer order submission or feedback writes enabled.
- Actual visit schema compatibility, Flutter build, and Supabase deployment remain unverified.
