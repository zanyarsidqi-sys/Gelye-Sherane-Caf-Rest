# Upgrade 1273 — Dashboard timestamp integrity

- Track the business day of the last successful non-empty overview snapshot.
- Do not advance the last-loaded time for empty responses or requests that finish after the selected day changes.
- Show the timestamp only when it matches the currently selected business day.
- Existing RPCs, permissions and other screens unchanged.

Validation: archive integrity and static assertions only; Flutter SDK and Supabase runtime not available.
