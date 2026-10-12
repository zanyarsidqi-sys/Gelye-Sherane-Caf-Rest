# Upgrade 1168 — Kitchen stale handover dialog guard

A Kitchen served-order item fetch can finish after the employee refreshes or
switches queue context. Previously the old asynchronous operation could still
open a stale handover dialog (although a later token guard prevented submission).
The code now validates the confirmation token and confirming order immediately
after item fetch, **before** showing the dialog.

Source-level tests only; Flutter compilation and Supabase staging acceptance
remain deferred at user request. Next: Section 05 design previews and integration.
