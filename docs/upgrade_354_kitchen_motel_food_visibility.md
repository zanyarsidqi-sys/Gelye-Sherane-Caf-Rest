# Upgrade 354 — Accepted motel food requests in Kitchen

- Adds a separate read-only **Motel Food Requests** tab to the employee Kitchen screen.
- Backend `gs_kitchen_list_accepted_motel_food()` checks authenticated Kitchen `can_view` permissions and returns only accepted guest food requests with room and item details.
- Pending/rejected requests are excluded. Requests are displayed using the server-captured Tourism Mode price snapshots.
- No kitchen ticket dispatch, preparation state changes, inventory deductions, room billing, or guest notifications are implemented by this upgrade.
- Flutter compilation and live Supabase migrations are not tested in this environment.
