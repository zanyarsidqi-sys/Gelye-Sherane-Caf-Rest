# Dashboard Upgrade 1288

Section 01 only. Protect authoritative Dashboard overview metrics against accidental overwrites from the optional operational-metrics RPC. The extension now adds keys only when absent from the main overview; existing keys, including null values, remain authoritative. No backend RPC definitions or other management sections were changed.

Verification: ZIP CRC check, byte-for-byte preservation of all original archive entries except dashboard_screen.dart, source assertions. Flutter compilation, live permission checks and Supabase integration remain unverified.
