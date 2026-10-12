# Upgrade 295 — Multi-table and whole-café conflict protection
Added database triggers for approved events and ordinary reservations using a shared transaction-level advisory lock. Event approval validates capacity, all selected tables or the whole venue, and overlapping approved bookings. Ordinary reservation writes reject overlap with approved events. Table assignments on approved events cannot be changed.

Not deployed or compiled. Live database tests, ordinary-to-ordinary conflicts, and all staff/public pathways remain to be verified. Public event submissions are still disabled. These guards must be verified on a staging database before production use.
