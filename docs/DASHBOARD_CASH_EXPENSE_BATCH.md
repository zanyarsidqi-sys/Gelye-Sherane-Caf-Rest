# Dashboard Cash and Expenses — development batch 2

17 October 2026. Continues the approved 96-card design review. Development only; no production publication in this batch.

## Implemented

- Shared executive navy/gold finance surfaces with readable errors.
- Cash In and Owner Cash Out show their matching journal kinds.
- Journal search by reason, review reason, amount or method; search never recalculates the server balance.
- Clear stale balances, rows and capabilities at refresh start; errors do not leave financial actions available against stale records.
- Ignore late read responses after changing card, refresh or disposal.
- Display last successful refresh time in Baghdad time.
- Expenses overview includes paid purchases; Pending Expenses and Accounts Payable start with unpaid items.
- Overdue expense filter uses the Baghdad calendar date, excluding paid balances and missing/future due dates.
- Separate loaded outstanding balance from matching outstanding balance.
- Invalid timestamps display a dash rather than crashing or inventing a current date.

Shared surfaces affect seven Dashboard cash routes (Standing Cash, Cash Out — Owner, Remaining Cash, Cash In, Expected vs Actual Cash, Financial Alerts, Cash Reconciliation) and three expense routes (Expenses, Pending Expenses, Accounts Payable). These are affected screens, NOT ten completed domain workflows. Payment Management also reuses these surfaces.

## Preserved

Cash entry and approval handlers, expense creation/payment/evidence handlers, and complete financial form classes are byte-identical to the original source. Existing server capabilities and permission scopes are preserved. No database, balance, ledger or settlement changes.

Automatic review initially rejected the cash and expense full-file writes. Exact identity checks of all financial mutation handlers and form classes were provided; both writes were subsequently approved.

## Still pending

Standing Cash still opens the recorded cash journal, not the approved unpaid-table-bill workflow. Financial Alerts is not a full exception engine. No cashier discount, credit settlement, per-item split billing, automatic date inheritance or advanced supplier ledger is introduced. No card is represented as fully complete solely because it uses the new design.

## Verification

Six focused tests added for timestamp fallback, journal filtering/permission scope, stale cash controls, asynchronous races, overdue matching totals on an RTL phone viewport, and expense refresh/retry. Existing expense evidence/payment regression remains in the test suite. CI status is recorded in the pull request.
