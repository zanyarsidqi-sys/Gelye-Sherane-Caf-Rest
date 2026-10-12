# Upgrade 1379: Cash reconciliation source-aligned scope disclosure

- Uses a single named 100-order server fetch limit instead of an inline magic number.
- Shows a clear warning when 100 authorized orders are returned: filtering and bottom totals apply only to loaded records, not all historical transactions.
- Clarifies the visible/loaded order count in the Material UI.
- No changes to settlement attestation, RLS, RPC authorization, or invoice print/save.
- Static ZIP integrity and source assertions passed; Flutter build, Supabase live testing and 95% pixel similarity remain unverified.
