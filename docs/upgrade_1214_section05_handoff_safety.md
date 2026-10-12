# Upgrade 1214 — Section 05 source-level handoff safety

- Table Orders notification acknowledgement invalidates an in-flight poll before refreshing, avoiding stale unread counts.
- Kitchen delivery queue now guards overlapping manual loads and ignores late results after disposal or newer loads.
- These are source-level protections only. Flutter compilation, Supabase migration verification, and iPhone/Windows device review remain deferred.
- Section 05 mockups require owner approval before moving to Section 06.
