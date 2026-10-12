# Upgrade 1256 - Kitchen product routing and station assignment UI guards

Source changes:
- Product routing now uses the authorized station directory, handles empty stations, and requires confirmation before changing future product routing.
- Blocks concurrent routing updates and checks the active employee session after asynchronous loads and confirmations.
- Employee assignment UI discards stale async loads and blocks actions after employee session changes.
- Station administration remains in Section 05 Kitchen; no Workplace integration was introduced.

Security limits: UI controls are defense in depth; the database RPCs must enforce all station permissions, employee assignments and MFA. These changes do not alter historical tickets, invoices or payment data.

Outstanding: validate real customer-name projection, actual device session flow, all server-side RPC permission boundaries and printer integrations with staging data. Flutter compilation, live Supabase and printer hardware tests were intentionally deferred.
