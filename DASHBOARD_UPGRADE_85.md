# Dashboard Upgrade 85 — Cumulative reversal protection (draft)

Replaced the Upgrade 84 reversal trigger function with a stricter version.
The function locks the original credit entry `FOR UPDATE`, sums existing debit
refunds/reversals referencing that payment, and rejects any new entry whose
amount would exceed the original payment after previous reversals.

It also rejects reversing another refund, self-references, and cross-order
references. The existing append-only trigger remains in force. No new client
posting privileges or refund endpoint were granted.

**Not verified:** real concurrent PostgreSQL execution, alternative transaction
isolation levels, integration with a payment provider, cash refunds, owner
waivers, or credit-account reversals. This is a database safeguard, not a
complete refund workflow. Run concurrent insertion tests in a disposable
Supabase staging environment before relying on it.
