# Dashboard Upgrade 1299

Section 01 only. Weekly trend validation now rejects whole-number order counts and IQD cash figures outside JavaScript's exact integer range (2^53 - 1). This prevents misleading rounded financial/count values on Flutter web. Valid signed whole-dinar adjustments and permission-hidden cash values remain supported.

Verification: ZIP CRC, archive preservation, source assertions, cross-project source parity. Flutter SDK and live Supabase not available; compile and runtime checks pending.
