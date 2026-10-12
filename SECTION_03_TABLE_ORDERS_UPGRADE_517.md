# Upgrade 517 — Foreground revalidation and safe instruction submission

- The staff fulfillment board refreshes on application resume so outdated authorization and visit data are not used after returning from background.
- Refresh requests during an in-progress edit/fulfillment transition remain deferred through the existing queue.
- After an instruction-edit dialog closes, the board freshness and item status are checked again before invoking the existing audited Supabase revision RPC.
- The backend remains authoritative for permissions and concurrent revisions.
- Quantity changes, transactional repricing, and live Supabase verification remain outstanding.
- Flutter compilation and integration tests were not performed in this environment.
