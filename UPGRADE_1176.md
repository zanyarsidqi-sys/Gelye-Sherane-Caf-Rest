# Upgrade 1176 — Kitchen completed orders and history

Adds `kitchen_completed_at` with a database trigger stamping transitions to `served`; no backfill of historic served orders because their real completion times are unknown. Adds **Today’s Completed** and **History** (today, yesterday, last 7 days, last 30 days) views with server-side date filtering in Asia/Baghdad business dates. Other status views remain.

This is the first history increment: individual item delivery/employee timeline, full-text search, and custom ranges still need implementation. Supabase migration and Flutter compilation remain deferred pending laptop verification.
