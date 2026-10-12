# Upgrade 1155 — Session-safe handover item-load errors

The item-loading failure snackbar is now restricted to the original signed-in
employee and original queue generation. A previous employee's asynchronous
failure cannot produce a misleading message after account switching.

Both upgrades are source-level only. Flutter compilation and live Supabase
acceptance remain deferred until laptop testing.
