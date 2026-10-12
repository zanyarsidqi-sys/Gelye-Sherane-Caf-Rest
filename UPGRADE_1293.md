# Dashboard Upgrade 1293

Section 01 only. Harden gs_dashboard_week payload validation: reject more than seven rows to prevent an overwide weekly chart, and reject missing/null `orders` rather than silently displaying zero. Existing count validation, retry UI, RPC arguments and other modules are preserved.

Verification: archive CRC check, all previous members preserved, unchanged members byte-for-byte, static source assertions. Flutter SDK and live Supabase were not available; compilation/runtime not claimed.
