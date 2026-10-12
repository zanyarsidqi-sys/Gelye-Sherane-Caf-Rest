# Upgrade 1290 — Validate weekly chart RPC data

Section 01 Dashboard only. The `gs_dashboard_week` response is validated as a list of string-keyed maps with numeric or null `orders` before FutureBuilder renders the chart. Unexpected structures now throw FormatException and use the existing safe weekly error/Retry trend UI, rather than causing unchecked casts in the widget build. Existing chart layout, RPC parameters, permissions and other project files remain unchanged.

Validation: ZIP integrity and exact preservation of all original entries except dashboard_screen.dart; targeted static source checks. Flutter SDK/live Supabase unavailable here; runtime unverified.
