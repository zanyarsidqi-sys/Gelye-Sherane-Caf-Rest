# Upgrade 1294 — Dashboard weekly business-day integrity

- Validate every populated weekly chart row has a canonical YYYY-MM-DD business day.
- Reject duplicated days and days outside the requested seven-day reporting window.
- Preserve empty [] response for employees without table/motel order permissions.
- Preserve existing order count validation, retry UI, other sections and project files.
- Static source and ZIP integrity checks performed; Flutter SDK and live Supabase verification unavailable.
