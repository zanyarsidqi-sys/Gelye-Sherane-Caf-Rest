# Upgrade 1296: DST-safe weekly reporting dates

Section 01 Dashboard only. Compare requested and returned YYYY-MM-DD calendar days as UTC midnights, rather than device-local midnights. This avoids a daylight-saving transition causing the six-day lookback to shift by an hour and incorrectly reject a valid first day of the week. Existing strict date validation, duplicate checks, chronological sorting, chart, permissions and RPCs remain intact.

Static source and ZIP integrity checked; Flutter/Dart SDK and live Supabase are unavailable, so compilation and runtime integration remain unverified.
