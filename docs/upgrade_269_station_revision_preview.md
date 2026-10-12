# Upgrade 269 - Station revision preview

Read-only, staff-authorized RPC `gs_staff_revision_station_preview` shows the preparation station, product, original and changed snapshots, actor, timestamp and revision-print queue state. Intended for later revised ticket design. No automatic station printing, notification delivery, customer feedback or order mutation is implemented here. The only existing revision writer (266) edits instructions before station acceptance, and deliberately does not create a redundant print ticket. Flutter compile and live database deployment remain untested.
