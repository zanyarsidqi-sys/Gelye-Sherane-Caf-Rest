# Upgrade 1487

Shared across all 35 registered sections: invalidates session-only shift handover reviews when the app is backgrounded, manually privacy-locked, or section navigation changes. Review mutation and copying require an unshielded, unchanged authenticated employee. Prevents old checkmarks from appearing as a new shift's completed review.

Read-only SQL staging schema gate added but NOT executed. Invoice/unified-ledger settlement, paid-state reconciliation, Standing Cash/Pending Payment and certified IQD totals remain blocked.

Rollback: restore complete previous ZIP. No database migrations applied.
