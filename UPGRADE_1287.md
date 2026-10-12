# Upgrade 1287 — Dashboard authorization-safe failure messages

- Centralize overview and weekly trend error descriptions.
- Distinguish timeout from PostgreSQL/PostgREST authorization failure (42501, PGRST301, PGRST302) without showing raw backend error details.
- For other errors, provide a neutral retry/administrator message instead of incorrectly assuming migrations are missing.
- Preserve existing request, retry, card and permissions behavior.
- Validation: ZIP CRC, original entry byte preservation, targeted source assertions. Flutter compilation and live Supabase integration not performed.
