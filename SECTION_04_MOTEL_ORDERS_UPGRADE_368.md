# Upgrade 368 — Identity-aware invoice draft reviews

Adds a deterministic fingerprint of individual food order IDs, room IDs, delivered timestamps, prices, statuses, and item line IDs/totals. New reviews store this fingerprint. A review becomes stale if its fingerprint differs, even when the order count and sum are unchanged. Authorized audited re-review accepts such changes and retains the previous fingerprint in review history. Older reviews without a fingerprint require re-review. No official invoice or payment is created.

Validation: archive integrity only; Flutter and live Supabase migration not executed.
