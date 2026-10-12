# Upgrade 605 — Kitchen handover confirmation session boundary

Fixed a cross-employee handover confirmation race: the original dialog could stay open while another employee logged in and refreshed the kitchen queue. The resulting action could then run as the second employee.

The employee identity and queue generation are captured before opening the confirmation dialog and rechecked after it closes, before submitting any kitchen status update. The `_advance` method also requires the original identity and queue generation. Any change requires a fresh confirmation.

No new database migration. Backend permission and transition validation remain mandatory.

Verification: static regression assertions only. Flutter compilation, live Supabase, and interactive session-switch testing are still required.
