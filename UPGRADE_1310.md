# Dashboard Upgrade 1310

Section 01 only. Fix seven-day order chart's zero-order display: zero counts now produce zero-height bars instead of a misleading two-pixel bar. Nonzero counts retain their previous proportional scaling and minimum visibility. Weekly RPC validation already normalizes validated order counts to int; this change uses that contract. No other existing project file changed.

Verification: ZIP integrity, archive preservation and source assertions passed. Flutter SDK and live Supabase testing unavailable here.
