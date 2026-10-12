# Payments list subtotal

Adds a bottom-of-list subtotal for the posted motel finance invoices in the existing Flutter handoff panel. The sum uses exactly the rendered postedInvoices rows and includes the row count. If a total is missing or malformed, the aggregate is marked unavailable rather than misleadingly displayed. No payment mutation or invoice printing was enabled.

Scope: This is a first incremental implementation, NOT the full requested card/date/user/cash/credit filtering feature. Other financial lists and cross-section totals remain pending.

Verification: archive integrity and static source assertions only; Flutter compile and Supabase integration not run.
