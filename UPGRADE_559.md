# Upgrade 559 — Replacement confirmation UI correctness

- Fixed replacement reason entry not refreshing the enabled state of Review replacement.
- Validates all server quote money fields are integral IQD and checks arithmetic consistency, quantity, and original unit price before showing the final confirmation.
- No schema changes. Existing permissions, kitchen and invoice guards remain server-enforced.
- Static tests only; Flutter SDK and live Supabase are unavailable in this environment.
