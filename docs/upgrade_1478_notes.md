# Upgrade 1478: universal privacy shield + identity settlement gate

- All 35 registered SectionShell routes receive a manual privacy shield, hiding authorized content and requiring a fresh server-backed permission check to reveal it. This is UI privacy, not a replacement for Supabase RLS.
- A read-only identity settlement gate checks prior independent approval and returns explicit non-settlement flags. It does not establish authentic source evidence, change paid status, or write a unified ledger.
- Staging preflight is provided but has NOT been executed against a real database. No credentials or Flutter toolchain are available here.
- Rollback: restore the preceding ZIP. SQL migration adds a function; drop it only after checking dependencies.
