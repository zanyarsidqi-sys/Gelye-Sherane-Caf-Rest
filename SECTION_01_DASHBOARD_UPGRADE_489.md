# Upgrade 489 — Dashboard seven-day cash totals and date validation

- Validate that the cash trend contains seven distinct consecutive business dates before displaying it.
- Sort the seven-day cash trend chronologically.
- Show weekly totals separately for table and motel cash collections only if all seven authorized daily values are valid.
- Show a combined weekly total only if both ledgers are complete and accessible.
- Explicitly mark incomplete or permission-restricted weekly totals as unavailable.
- Preserve the classification as unreconciled cash collections; these figures are not revenue, profit, or credit transactions.
- No new SQL migration is needed.

## Verification
Static patch assertions and ZIP integrity checks only. Flutter compile and live Supabase tests are pending.

## Progress
Section 01 Dashboard: 84% provisional development estimate; not verified.
