# Upgrade 1368: cash reconciliation filtered-list total

The authorized cash reconciliation sample now calculates its cash sum from the exact rows matching cash-status and ledger-warning filters. The sum and matching row count are rendered after the scrollable transaction list. Malformed amounts continue to suppress a misleading total. This is a cash-only, capped sample, not all-method revenue or complete Standing Cash/Pending Payment coverage. No new printing, saving, or settlement actions were enabled.

Verification: ZIP CRC, source assertions, preserved original archive paths. Flutter compile and live Supabase tests pending.
