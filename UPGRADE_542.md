# Upgrade 542 — Kitchen revision receipt confirmation and migration dependency repair

Section 03 Table Orders. Requires a deliberate employee confirmation before acknowledging actual kitchen receipt of a replacement revision; distinguishes receipt from printing/preparation/delivery. Adds a manual status refresh to the revision dialog. Corrects the source ordering in migration 539 so its audit table is created before the acknowledgment function references it; this is essential for clean sequential deployment. No existing database was modified.

Deployment: If migration 539 has not been applied, deploy the corrected 539 followed by 540 and 541. If 539 was already applied, review migration history before altering an applied migration; do not blindly replay it. Upgrade 542 has no new schema changes.

Verification: ZIP CRC, source assertions and migration ordering checked; Flutter compilation and live Supabase tests not run.
