# Upgrade 268: revision notification and printing status

Adds a permission-checked, read-only staff RPC for revision dispatch rows and
an Employee Order Board dialog to inspect destination, queue status and attempts.

This is **queue visibility only**. It does not send push notifications,
print physical tickets, or enable product/quantity editing. Deploy migration
and run Flutter/Supabase integration tests before production use.
