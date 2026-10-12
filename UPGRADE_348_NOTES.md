# Upgrade 348 — Scheduled Meal Queue Visibility

Staff Scheduled Meals now supports All, Needs approval, In progress, and Overdue filters, pending/overdue counts, and overdue labels. Overdue means the requested delivery time is in the past while the meal is not delivered/rejected/cancelled. This is a UI calculation using the timestamp returned by the existing staff RPC; no backend workflow or kitchen dispatch is implied.

Unverified: Flutter compilation, Supabase integration, kitchen tickets, active-stay linkage and actual room charges. Section 04 estimated progress remains 43%.
