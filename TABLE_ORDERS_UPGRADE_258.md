# Upgrade 258: Customer QR Menu UI (read-only cart preview)

Added CustomerTableQrMenuScreen, opened automatically for a browser URL with a nonempty `token` query parameter. It fetches gs_public_table_menu, displays table-scoped prices, searchable items, quantity selectors, and an itemized local cart total. Refresh clears stale cart price quotes.

**Security:** This is a display-only cart; order submission deliberately disabled pending verified visit-scoped authorization, server-side re-pricing and audit. QR token alone must not authorize orders, service requests or private bill access. This does not yet include photos, modifiers, individual bills or real-time price push updates.

**Testing:** ZIP integrity validated only; Flutter compile, Supabase deployment and end-to-end tests remain pending.
