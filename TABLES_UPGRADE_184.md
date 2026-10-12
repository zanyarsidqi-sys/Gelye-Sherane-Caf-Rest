# Upgrade 184 — Counter Order Submission for Review

Added an authorized, atomic submission step for takeaway/delivery
menu-priced drafts. The backend locks the request, requires at least
one priced item, records an immutable-by-permission submission event
with total and item count, and moves the request from `pending` to
`accepted`. A second submission is rejected, preventing duplicate
review submissions. Draft items cannot be edited afterward via
existing RPCs.

**Not a kitchen dispatch.** There is no kitchen ticket, inventory
movement, real order creation, employee delivery assignment, notification
dispatch, or payment posting. These require cross-module integration and
live verification. The Flutter button explicitly says *for kitchen review*
and warns no ticket is created.

ZIP integrity verified; no Flutter build or live Supabase migration test.
Section 02 Tables remains ~60% estimated; this upgrade advances
Section 03 Table Orders.
