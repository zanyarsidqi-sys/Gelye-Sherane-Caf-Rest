# Upgrade 1229 — Station POS print worker foundation

Added a Dart station POS worker with polling, station ticket formatter, optional customer names / Guest N / Table Order fallback, and explicit ORDER/CORRECTION/REPLACEMENT/CANCELLATION labels. It uses the device session service from Upgrade 1228. Print adapters return printed, definitelyFailed, or uncertain. Uncertain results and failed acknowledgments are quarantined for manual review, not blindly retried.

**Integration gaps (critical):** The database claim RPC currently returns only ticket metadata; a trusted station-scoped immutable ticket-content resolver must be implemented before this worker can run. No physical ESC/POS or other printer adapter is included, and this worker is not wired into the POS screen lifecycle. No verified physical printing, correction routing, or cross-device idempotent reconciliation yet. No bill printing. This is source infrastructure, not an operational automatic printer.

ZIP integrity and static content checks only. Flutter compilation, live Supabase and physical printer tests deferred.
