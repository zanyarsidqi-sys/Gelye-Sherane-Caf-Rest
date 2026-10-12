# Upgrade 564 — Ambiguous replacement outcome handling

Section 03: Table Orders.

- Separates pre-submission failures from ambiguous post-submission RPC failures.
- Does not claim an RPC failure proves transaction rollback.
- Read-only lookup checks current product, unit price, and quantity; this is diagnostic, not proof of the request identity.
- Instructs staff to review kitchen revision history and avoids automatic mutation retries.
- Preserves prior project files and migrations.

Verification: static source assertions and ZIP CRC only. Flutter SDK and live Supabase environment unavailable.
