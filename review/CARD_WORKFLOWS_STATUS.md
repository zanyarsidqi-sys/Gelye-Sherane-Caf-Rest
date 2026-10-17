# Card workflows — incomplete development checkpoint

## Current source
- Repository: zanyarsidqi-sys/Gelye-Sherane-Caf-Rest
- Development branch: codex/table-card-workflows
- Base main commit: 79012d0526f77b8b7c5527e2c83304da111a19bc
- Feature checkpoint: b88934452481a0dc48dd90f871a6e85f8b6713dc
- Test repair: 08555f02b3e08c1970de47b37a94f830fd4983d1
- Keep Style 2. No section is verified 100% complete.

## Source changes present
- Owner price input permits zero; Normal/Tourism remain positive.
- Category add/rename and product image upload/preview/remove screens.
- Product editor category dropdown; menu image references.
- SQL migrations for Owner zero, category/image operations and image access.
- Table task migration for maintenance, chairs, waiting and grouping.
  Corresponding complete Flutter workflows remain unfinished.

## Verification as of 17 October 2026
- Previous GitHub run 39022257170: analysis passed, 78 tests passed, one failed.
- Failure: catalog_orders_test.dart tried entering text into Category after it
  became a DropdownButtonFormField.
- Repair selects Drinks from the dropdown and verifies its saved category.
  The same save-flow test now verifies Owner price zero.
- Repair run: https://github.com/zanyarsidqi-sys/Gelye-Sherane-Caf-Rest/actions/runs/39023246234
- Repair run completed successfully: Flutter analysis, tests and release web build passed.
- This verifies the repair commit, not production behavior or unfinished features.
- Prior checkpoint reported staging rollback tests for Owner zero and zero-total
  orders. Those database tests have NOT been rerun in this continuation.
- Product image uploads and narrowly permissioned staff access remain unverified
  end to end.
- No production migration, merge or deployment was performed in this continuation.

## Remaining requested work
1. Complete and test all-card/selected-card permissions plus date scope:
   today; yesterday + today; yesterday + today + future; custom range; all history.
   Use Asia/Baghdad boundaries and enforce on the server, including searches,
   reports and exports. Hiding UI controls alone is insufficient.
2. Implement cashier discount in Table Overview > Print Bill:
   250–4,750 IQD fixed discount for authorized cashiers without separate manager
   approval within that range. No increment size was specified.
   Show existing/available discounts and require one explicit selection; no silent
   stacking. Do not change pricing mode or paid historical items.
   Validate eligible unpaid charges server-side. Preview gross, discount,
   payments and balance. Printing must not post payment or free the table.
   Audit cashier, time, bill/visit, amount and reason; retries must not duplicate.
   This remains a requirement, NOT implemented or deployed.
3. Complete requested operational workflows across Tables, all 49 Menu cards,
   Kitchen, Motel/Online and Payments, beyond generic record forms.
4. Verify image access and public menu rendering end to end.
5. Verify financial, authorization and concurrency behavior; reconcile staging
   migration state before applying anything further.
6. Complete release checks and obtain applicable deployment authorization;
   verify actual deployed version/footer after any future release.

## Historical blockers
The prior checkpoint recorded rejected local Flutter setup and GitHub upload
attempts. Do not retry the rejected local metadata-access setup.
The branch now contains the uploaded source and runs GitHub Actions; the old
statement that the remote branch contains only the baseline is superseded.
