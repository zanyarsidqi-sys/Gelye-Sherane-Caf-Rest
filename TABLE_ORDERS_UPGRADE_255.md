# Upgrade 255 — Table checkout mode reset

- Adds database trigger to reset Tourism Mode to Normal whenever a table transitions from occupied to released.
- Deactivates that table's Admin Discount Mode and resets its base mode to Normal.
- Audits discount changes when an authenticated employee performs the release.
- Does **not** bypass existing checkout settlement/cleaning authorization; it only reacts to successful release.
- Does not modify historical order item prices, invoices or settlements.
- Important: customer QR session revocation, any standalone Owner Mode field, live database migrations, Flutter compilation and integration tests remain outstanding.
