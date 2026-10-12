# Phase 3 — Step 3: Kitchen-to-inventory integration

Added migration `20261009_027_kitchen_inventory_consumption.sql`.

When an authorized kitchen employee changes an order from `ready` to `served`, the database atomically deducts quantities for **explicitly stock-tracked menu products**. If tracked stock is insufficient, the status change and all deductions roll back. Every deduction records an employee-linked movement and an order/product consumption record. Repeated served transitions are already disallowed by the kitchen status function.

**Scope:** Finished menu products mapped one-to-one to stock units only. Recipe ingredients, portions, wastage, refunds, order cancellation reversals, and stock reservation at order creation are not implemented. Products without a row in `gs_inventory_stock` are intentionally not deducted. Staff should not manually stock-out the same served items or stock will be counted twice.

**Deployment:** Apply migration 026 before 027 in staging; check permissions and trigger compatibility. Test one-item and multi-item orders, insufficient stock, simultaneous handovers, untracked products, and movement audit. No live database migration or Flutter build was executed in this update.

**Progress:** Previous project-wide implementation estimate 61% (unverified); not recalculated. Step 3 remains in progress; Steps 4–8 remain, plus unfinished payment integrations and final 35-section verification.
