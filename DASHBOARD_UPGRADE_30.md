# Dashboard coding upgrade 30

Added read-only reservation, guest-by-guest billing, orders, and payment record details to Live Table Map detail view. The UI shows only supplied backend fields, never fabricates amounts, and does not mutate payments or reservations. Missing data is explicitly marked unavailable. Existing iPhone full-screen and Windows side-panel presentation remains.

Remaining: authorized backend detail endpoints, capacity-safe guest adjustments, table transfer and reservation cancellation transactions, split payment ledger and credit/online confirmation security, Flutter compile and Supabase deployment.
