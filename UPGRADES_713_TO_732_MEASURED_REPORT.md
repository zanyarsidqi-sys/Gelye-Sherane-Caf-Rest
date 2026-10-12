# Upgrades 713–732 — measured acceptance checkpoints

This batch contains 20 **source-contract acceptance checkpoints**, not 20 independently runtime-tested features. The only code behavior changed in this batch is sanitizing the Menu product-creation error message.

| Upgrade | Section | Check | Before | After | Change |
|---|---|---|---|---|---|
| 713 | 01 Dashboard | Operational server summary | Pass | Pass | +0 check |
| 714 | 01 Dashboard | Cash collection server source | Pass | Pass | +0 check |
| 715 | 01 Dashboard | Weekly trend server source | Pass | Pass | +0 check |
| 716 | 02 Tables | Server-side table state | Pass | Pass | +0 check |
| 717 | 02 Tables | Reservation cancellation | Pass | Pass | +0 check |
| 718 | 02 Tables | Table transfer financial preflight | Pass | Pass | +0 check |
| 719 | 03 Table Orders | Server-side board pagination | Pass | Pass | +0 check |
| 720 | 03 Table Orders | Idempotent replacement confirmation | Pass | Pass | +0 check |
| 721 | 03 Table Orders | Kitchen replacement receipt status | Pass | Pass | +0 check |
| 722 | 04 Motel Orders | Room registry integrated | Pass | Pass | +0 check |
| 723 | 04 Motel Orders | Food ledger integrated | Pass | Pass | +0 check |
| 724 | 04 Motel Orders | Scheduled meals integrated | Pass | Pass | +0 check |
| 725 | 05 Kitchen | Live kitchen status RPC | Pass | Pass | +0 check |
| 726 | 05 Kitchen | Scheduled motel meals queue | Pass | Pass | +0 check |
| 727 | 05 Kitchen | Motel food requests queue | Pass | Pass | +0 check |
| 728 | 06 Menu | Live product creation RPC | Pass | Pass | +0 check |
| 729 | 06 Menu | Tourism price field | Pass | Pass | +0 check |
| 730 | 06 Menu | Safe public failure message | Fail | Pass | +1 check |
| 731 | 07 Products & Inventory | Server inventory overview | Pass | Pass | +0 check |
| 732 | 07 Products & Inventory | Server inventory adjustment | Pass | Pass | +0 check |

## Section-by-section measured evidence

| Section | Before | After | Change | Verified completion |
|---|---:|---:|---:|---|
| 01 Dashboard | 3/3 | 3/3 | +0 passed checks | Not established |
| 02 Tables | 3/3 | 3/3 | +0 passed checks | Not established |
| 03 Table Orders | 3/3 | 3/3 | +0 passed checks | Not established |
| 04 Motel Orders | 3/3 | 3/3 | +0 passed checks | Not established |
| 05 Kitchen | 3/3 | 3/3 | +0 passed checks | Not established |
| 06 Menu | 2/3 | 3/3 | +1 passed checks | Not established |
| 07 Products & Inventory | 2/2 | 2/2 | +0 passed checks | Not established |

## Remaining work to a genuine 100%

A **step** is a testable acceptance task, not a fixed percentage or upgrade count. A reasonable initial planning backlog is 5–10 major acceptance tasks per section (35–70 tasks across seven sections), subject to defects found. This is **not** a measured countdown.

The following verification gates remain open for **each** of the seven sections: Flutter analyze/build; live Supabase migrations and permissions; core workflow end-to-end tests; cross-section consistency; employee-session and concurrency checks; and iPhone/Windows review.

Flutter SDK was not available in this execution environment. No live Supabase environment was configured. Do not deploy on the strength of these checks alone.

## Actual source change

`lib/shared/live_menu_product_create.dart`: employee-facing product creation failure no longer prints the raw Supabase exception.

## Reproduction

`python tools_section_audit_732.py`

`python -m pytest -q tests/integration/test_upgrade_732_section_acceptance.py`
