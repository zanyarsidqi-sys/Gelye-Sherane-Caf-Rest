# Upgrade 194 — Manager Job Reassignment

Added manager-only reassignment RPC and a Flutter dialog in Tables.
Requires a valid job number, employee UUID and reason. Uses row locking,
rejects inactive jobs and same-person assignments, records audit events,
and sends inbox events to the new employee, previous employee and creator
via the existing notification routing trigger.

In-progress product deliveries cannot be reassigned because physical
custody must be verified by a dedicated handoff process. Reassignment
of other active jobs resets them to Assigned.

The interface currently takes employee UUIDs, not an employee search list.
This is source implementation only: not Flutter compiled or Supabase tested.
ZIP integrity verified. Tables completion **73% estimated**.
