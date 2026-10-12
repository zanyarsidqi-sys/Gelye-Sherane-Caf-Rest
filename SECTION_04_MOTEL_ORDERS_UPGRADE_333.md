# Upgrade 333 — Section 04 Motel Orders

Cross-section review: Section 03 uses the same LiveOrderCreatePanel as Motel Orders. Existing backend service is retained, including server-selected Tourism Mode pricing for motel orders.

## Implemented
- Live motel order entry requires staff to manually confirm the destination with reception.
- Editing the room/villa resets destination and cart review confirmations.
- Submission is disabled until both confirmations are checked; validation also runs in submit handler.
- A successful submission clears the destination confirmation.
- Table Orders remains unchanged; shared component branches only for motel mode.

## Known limits
- This is a staff confirmation, not backend validation of motel occupancy. A future integration must link to actual guest/room records and enforce the link server-side.
- Flutter compilation and live Supabase testing have not been performed.
- Section 03 is still estimated at 69%, with financial integration/testing outstanding.
