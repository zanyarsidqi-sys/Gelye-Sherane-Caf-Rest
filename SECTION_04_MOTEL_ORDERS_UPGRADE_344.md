# Upgrade 344 — Scheduled meal staff decisions

- Authorized Motel Orders editors can confirm or reject `requested` meals.
- Rejection requires a reason. Status changes are serialized using row locks and audited.
- The employee Scheduled Meals screen includes Confirm and Reject actions.
- Confirmed is NOT paid, kitchen-dispatched, or authorized for a room charge.
- Customer status polling, kitchen dispatch, active occupancy integration, Flutter compilation, and live Supabase migration remain unverified/pending.
- Section 04 estimated progress: 39% (estimate, not test-verified).
