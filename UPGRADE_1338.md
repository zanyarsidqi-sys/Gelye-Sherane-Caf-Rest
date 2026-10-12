# Upgrade 1338 — Financial Overview & Payments

- Validates unique positive order IDs in the cash reconciliation response, failing closed instead of double-counting duplicated order rows.
- Flags inconsistent cash-only balance arithmetic (order total minus cash collected). This is a diagnostic, not a certified all-method balance.
- Adds a real Flutter chip labeling the cash ledger as a sample of at most 200 orders.
- Updates Dashboard integration comments while preserving the existing Standing Cash and Pending Payment fail-closed cards and all inspection actions.
- No new Supabase migration is required. No canonical allocations, posting, prepaid motel certification, or verified live totals are claimed.
- Flutter SDK unavailable in build environment; compilation and iPhone screenshot parity remain unverified.
