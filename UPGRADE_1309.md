# Upgrade 1309 — Dashboard weekly integer normalization

Normalize validated weekly order counts and cash IQD values to integers after checking finiteness, whole-unit amounts, and JavaScript-safe range. This fixes `7.0 orders` in labels/VoiceOver when a Supabase numeric field decodes as double. Keep missing/hidden cash null, signed adjustments, sorting, permissions and all other sections unchanged.

Verification: ZIP integrity, exact source assertions, previous entry retention, byte-for-byte preservation of other files. Flutter SDK, Supabase and device testing unavailable.
