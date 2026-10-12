# Upgrade 562 — replacement transaction integration regression suite

Added cross-version automated static contracts checking quote contents, employee-confirmed price, quantity and mode, legacy RPC access revocations, Flutter request payload, and kitchen revision guard presence. No database schema change or runtime UI behavior change.

Run: `python -m pytest tests/integration/test_upgrade_562_replacement_chain.py -q`

These checks are **not** a substitute for live Supabase concurrent transaction tests or Flutter compilation. Required staging scenarios: quote then switch pricing mode; quote then change quantity; simultaneous replacements; failed/missing kitchen dispatch; price update after quote; payment created before commit.
