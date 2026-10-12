# Upgrade 323 — Bill line integrity and counts

- Validate that every customer-visible bill line includes a non-empty product name; never silently substitute a generic label.
- Reject implausibly large quantities and line amounts before rendering.
- Display distinct product line count and total ordered units alongside gross order amount.
- Preserve visit-scoped access, refresh lifecycle, and gross-vs-outstanding-balance distinction.

## Verification
Static source inspection and ZIP integrity only. Flutter compilation and live Supabase testing not performed.
