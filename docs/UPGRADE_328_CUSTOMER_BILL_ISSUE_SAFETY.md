# Upgrade 328 — customer bill issue safety

- Preserve the table-visit token and request generation when opening the issue-reason selector.
- Discard an issue report if the session changes or the app becomes inactive before the selector closes.
- Bound the prefilled cashier request note to the existing 300-character server limit.
- No financial ledger reconciliation or automatic refunds are implied by this update.

Verification: archive integrity and code inspection only; Flutter and live Supabase tests not run.
