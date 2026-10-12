# Upgrade 688 — Inventory history request stability

## Issue
The stock history FutureBuilder created its Supabase RPC future inside the dialog builder. If the dialog was rebuilt, this could issue duplicate history reads and reset the loading state.

## Fix
Cache the future before opening the dialog and reuse it in FutureBuilder. Preserve employee session checks both before opening the dialog and when rendering the response.

## Verification
Run `python -m pytest -q tests/integration/test_upgrade_688_inventory_history_future.py`.
Flutter compilation and live Supabase tests remain outstanding.

## Section 01–07 completion
No verified completion percentages can be changed based on static checks alone. Section 03's previous 76% remains an unverified estimate.
