# Upgrade 1274 — Dashboard refresh timestamp clarity

- Dashboard overview header now displays the local calendar date and time of the last successful non-empty refresh, explicitly labeled as device time.
- This prevents an overnight refresh from appearing to have happened today based on time alone.
- Existing refresh, authorization, data, and navigation logic preserved.
- Static source checks and archive integrity only; Flutter runtime and Supabase not verified.
