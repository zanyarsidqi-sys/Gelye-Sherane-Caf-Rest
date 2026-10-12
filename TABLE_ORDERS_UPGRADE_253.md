# Upgrade 253 — Separate customer and staff order interfaces

- Staff/management: `lib/sections/table_orders.dart` retains its protected `SectionShell`, Table Orders and Takeaway & Delivery workspaces. Adds an explicit staff header and a customer-menu preview navigation action.
- Customer: `lib/shared/public_menu_screen.dart` remains a separate public menu, linked to public order request and order tracking screens. It is not embedded in the protected staff management workflow.
- The preview opens the public menu as a customer would see it, but it does **not** simulate a valid table QR token, and is not a live end-to-end QR table ordering test.
- No permissions are granted by the preview; no new public RPCs or payment permissions are introduced.
- Still required: secure table-specific customer cart and ordering, token validation, station routing for public table orders, UI testing and Flutter/Supabase integration testing.
