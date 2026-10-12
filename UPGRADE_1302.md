# Upgrade 1302: Accurate singular/plural order announcements

Section 01 Dashboard only. The weekly chart and weekly cash breakdown now announce “1 order” for a single order and “N orders” otherwise in their screen-reader semantics. Previously a count of one was announced as “1 orders”. No RPCs, business logic, permission checks, or visible layout changed.

## Verification
Static source checks and ZIP integrity/byte preservation were performed. Flutter compilation, device screen-reader behavior, and live Supabase were not tested in this environment.
