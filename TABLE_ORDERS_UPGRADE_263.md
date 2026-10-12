# Upgrade 263: authorized item event timeline

- New staff-only read RPC combines order creation, fulfillment transitions and audited instruction changes.
- Staff Order Board has a per-item history button with Iraq-local timestamps and before/after values.
- Order creation time is a parent-order timestamp, NOT necessarily item-added time.
- No claim that item-added timestamps, station print revisions, or delivery events outside the recorded fulfillment log are present.
- Requires deploying migration 263; not Flutter-compiled or live-tested.
