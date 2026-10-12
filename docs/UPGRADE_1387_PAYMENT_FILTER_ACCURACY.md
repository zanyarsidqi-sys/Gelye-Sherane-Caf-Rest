# Upgrade 1387 — Accurate payment-card filters

- Standing Cash no longer infers unpaid vs partially paid from a positive cash-only remaining amount.
- Pending Payment retains only source-verified unpaid invoice status; this is not proof of remaining balance.
- Added a Clear list filters control; source search, card-specific lists and filtered totals remain.
- Preserved both visible Pay buttons, server-authorized Standing Cash cash workflow, disabled Pending Payment collection, all other source files and navigation.
- Archive and source checks passed; Flutter compilation, live Supabase/RLS tests and screenshot matching not performed.
