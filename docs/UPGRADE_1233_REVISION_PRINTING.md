# Upgrade 1233 — revision device printing and A4 groundwork

Added service-role-only revision claim/resolve/ack SQL RPCs; station device identity, permissions, and lease checked server-side. Separate revision queue never auto-requeues unknown tickets. Flutter station session service and worker support distinct original/revision queue identities. Correction, replacement and cancellation tickets retain immutable event data and a reason. Printing never mutates customer bills. POS station ticket footer now says `Powered By Zanyar Sidqi`.

Added A4 official invoice field/schema layout foundation (210 x 297 mm), not yet a PDF renderer or legally validated tax invoice. Owner must configure actual legal company data. Existing POS and A4 receipt outputs still require shared invoice integration.

**Not yet operational:** Flutter POS lifecycle attachment, printer driver, revision authorization/security live tests, actual A4 PDF and print dialog, final receipt integration, all-35-screen footer integration. No compilation, Supabase live migration, or physical printer tests performed.
