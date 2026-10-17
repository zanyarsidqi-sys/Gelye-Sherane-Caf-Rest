# Card workflows — incomplete development checkpoint

User requested working placeholders across Tables, all 49 Menu cards, Kitchen,
Motel/Online, and Payments, followed by live deployment. Keep Style 2.
Additional explicit requirements: zero Owner price; category creation; product pictures.

## Actual changes
- Local Owner-price input validation permits zero; Normal/Tourism remain positive.
- Staging database permits Owner zero product prices and zero-total Owner orders.
- Local category add/rename screen and product image upload/preview/remove screen.
- Staging category/image schema and RPCs; actual image upload not end-to-end tested.
- Staging table task schema/RPCs for maintenance, chairs, waiting and grouping.
  Corresponding Flutter screens have NOT been created.
- Existing source copied from main commit 79012d0526f77b8b7c5527e2c83304da111a19bc.
- Local branch codex/table-card-workflows. Remote branch created at baseline only.
- NO production database migration, merge, release or live deployment performed.

## Verification
Staging transaction/rollback test passed:
- Owner zero accepted and zero-total order created.
- Zero Normal price rejected; negative Owner price rejected.
Separate category transaction test executed; see task conversation for its result.
Flutter analyze/test/build have NOT run.

## Blocking reviews
Local Flutter setup was automatically rejected for attempting cloud metadata access.
Do not rerun or bypass it.
Attempt to upload source/migrations/CI workflow to GitHub via create_tree was rejected:
explicit user authorization for destination
zanyarsidqi-sys/Gelye-Sherane-Caf-Rest is required.
No source tree/commit was successfully uploaded by that rejected call.

## Remaining
- Full requested card workflows, not merely generic record forms.
- Categories dropdown integration in product editor.
- Image upload access tests for narrowly permissioned staff and public menu rendering.
- Financial/authorization/concurrency tests for table changes.
- Table migration local final alias/overview patch has not been applied to staging;
  original base migration was applied.
- Remote GitHub Actions verification, then production migration/release gates.
- Update actual deployed footer/version only with verified release.
- Do not describe this checkpoint or any entire section as 100% complete.

## Added cashier requirement — 17 October 2026
In Table Overview > Print Bill, authorized cashiers can view available discounts
and directly apply a fixed 250–4,750 IQD discount without separate manager approval
within that range. No increment size was specified. Do not silently stack this
with another discount; show existing discounts and require one explicit selection.
Do not change the table's pricing mode or historical paid items. Validate against
eligible unpaid charges server-side; preview gross amount, discount, payments and
remaining amount. Printing alone must not post payment or free the table.
Record cashier, time, bill/visit, amount and reason; retry must not duplicate a
discount. This is recorded as a requirement, NOT implemented or deployed.
