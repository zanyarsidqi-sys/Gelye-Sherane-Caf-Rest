# Upgrades 733–752 — employee-facing error safety

20 individually measured corrections: raw Supabase exception text is no longer interpolated into selected employee-facing UI messages. No database changes.

| Upgrade | Section | File:line | Before | After |
|---|---|---|---|---|
| 733 | 02 | `lib/sections/tables.dart:75` | Raw exception exposed | Generic retry/manager message |
| 734 | 02 | `lib/sections/tables.dart:94` | Raw exception exposed | Generic retry/manager message |
| 735 | 02 | `lib/sections/tables.dart:108` | Raw exception exposed | Generic retry/manager message |
| 736 | 02 | `lib/sections/tables.dart:122` | Raw exception exposed | Generic retry/manager message |
| 737 | 02 | `lib/sections/tables.dart:137` | Raw exception exposed | Generic retry/manager message |
| 738 | 02 | `lib/sections/tables.dart:161` | Raw exception exposed | Generic retry/manager message |
| 739 | 02 | `lib/sections/tables.dart:183` | Raw exception exposed | Generic retry/manager message |
| 740 | 02 | `lib/sections/tables.dart:200` | Raw exception exposed | Generic retry/manager message |
| 741 | 03 | `lib/sections/table_orders.dart:164` | Raw exception exposed | Generic retry/manager message |
| 742 | 03 | `lib/sections/table_orders.dart:189` | Raw exception exposed | Generic retry/manager message |
| 743 | 03 | `lib/sections/table_orders.dart:314` | Raw exception exposed | Generic retry/manager message |
| 744 | 03 | `lib/sections/table_orders.dart:357` | Raw exception exposed | Generic retry/manager message |
| 745 | 03 | `lib/sections/table_orders.dart:400` | Raw exception exposed | Generic retry/manager message |
| 746 | 03 | `lib/sections/table_orders.dart:468` | Raw exception exposed | Generic retry/manager message |
| 747 | 03 | `lib/sections/table_orders.dart:676` | Raw exception exposed | Generic retry/manager message |
| 748 | 03 | `lib/sections/table_orders.dart:738` | Raw exception exposed | Generic retry/manager message |
| 749 | 06 | `lib/shared/live_menu_product_edit.dart:55` | Raw exception exposed | Generic retry/manager message |
| 750 | 06 | `lib/shared/live_menu_product_edit.dart:110` | Raw exception exposed | Generic retry/manager message |
| 751 | 06 | `lib/shared/live_order_create_panel.dart:134` | Raw exception exposed | Generic retry/manager message |
| 752 | 05 | `lib/shared/live_kitchen_panel.dart:172` | Raw exception exposed | Generic retry/manager message |

## Before/after metrics

| Section | Selected unsafe messages before | After | Corrected |
|---|---:|---:|---:|
| 01 | 0 | 0 | 0 |
| 02 | 8 | 0 | 8 |
| 03 | 8 | 0 | 8 |
| 04 | 0 | 0 | 0 |
| 05 | 1 | 0 | 1 |
| 06 | 3 | 0 | 3 |
| 07 | 0 | 0 | 0 |

**Important:** The numbers above are a security hygiene metric on selected UI messages, not a section completion percentage. Other exception strings may still exist and require review. Flutter SDK and a live Supabase project were unavailable, so no runtime readiness percentage is established. Section 03 retains its earlier unverified 76% estimate.

## Remaining steps

Estimated 35–70 major acceptance tasks across Sections 01–07 before a credible production readiness decision, subject to actual Flutter compilation, Supabase integration, security tests, real workflows, and iPhone/Windows review. This is not a measured countdown.
