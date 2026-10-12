# Upgrade 482 — Dashboard seven-day data integrity and trend comparison

- Dashboard daily metric cards accept only finite, nonnegative whole-number counts. Missing, fractional, and invalid values display Restricted / unavailable instead of being displayed as authoritative counts.
- Weekly reporting rejects invalid counts, partial data, duplicate dates, and nonconsecutive days, preventing misleading averages and trends.
- Added a transparent recent-three-days versus first-three-days order-volume comparison, excluding the middle day. This is operational order count only, not financial revenue.
- All earlier functionality and migrations preserved.
- Section 01 development estimate remains 83%; verification pending Flutter analyzer, Supabase migrations, RLS and real end-to-end workflows.
