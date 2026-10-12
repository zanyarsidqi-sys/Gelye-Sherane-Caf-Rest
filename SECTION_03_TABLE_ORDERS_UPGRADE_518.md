# Upgrade 518 — Manual Kitchen Handoff Integrity

- Blocks copying a potentially incomplete kitchen handoff when the authorized board reaches its 500-item response cap.
- Adds an explicit confirmation dialog with filtered item count and summed units; clearly distinguishes clipboard copy from kitchen dispatch.
- Revalidates board freshness and item membership after the dialog before copying.
- Sanitizes untrusted product names to prevent embedded newlines/control characters from forging rows in the clipboard report.
- Preserves all existing Supabase migrations and previous features.

Quantity editing, transactional repricing and kitchen revision dispatch remain unimplemented in this upgrade. Flutter compilation and live Supabase testing were not performed.
