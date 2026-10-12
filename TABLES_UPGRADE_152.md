# Section 02 — Tables — Upgrade 152

Adds `gs_check_in_cafe_reservation(uuid)` for approved reservations. The
function locks against concurrent approvals/walk-ins, checks the approved
reservation window (up to 30 minutes early), enforces unique numeric
reservable-to-café table mapping, validates capacity, occupancy and cleaning,
creates a Normal Mode visit, marks the table occupied, and stores a durable
reservation-to-visit link. Retrying the same check-in returns the existing
visit ID rather than opening a duplicate. No bill or payment is moved.

**Limits:** This is SQL code, not a wired Flutter reservation check-in button.
Mapping uses numeric `table_label`; mismatches fail closed. The reservation
approval workflow still needs mapping hardening and staging tests. No live
Supabase test was run. Dashboard remains paused at 149; Phase 3 ~54%
estimated, not verified. Next: UI integration and reservation audit/tests.
