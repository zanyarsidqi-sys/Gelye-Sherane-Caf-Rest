# Upgrade 493 — Dashboard cross-report comparison hardening

## Actual changes
- The daily/weekly cash comparison now locates the Iraq-local business date by value, rather than relying on the last row in a potentially unsorted response.
- Rejects duplicate, missing, and malformed business dates before comparing cash ledger totals.
- Requires both snapshots to carry the cash-collections-only, unreconciled, Asia/Baghdad metadata before comparing.
- Keeps restricted ledgers out of the comparison; does not infer missing amounts as zero.

## Limitations
- This is a source-level fix. Flutter compilation, live Supabase migrations, and accounting reconciliation were not executed.
- Section 01 remains at 84% provisional development progress. Other sections: Tables 94% estimated; Table Orders 69% historical; Motel Orders 91% estimated.
- Cash collections are not revenue or profit. Credit settlement remains disabled.
