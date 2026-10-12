# Upgrade 347 — Scheduled meals staff refresh

The staff scheduled meals queue now polls every 15 seconds while foregrounded, refreshes on resume, avoids overlapping fetches, and disposes its timer and lifecycle observer. This is foreground polling, not background push or kitchen integration.

Flutter and live Supabase tests not run.
