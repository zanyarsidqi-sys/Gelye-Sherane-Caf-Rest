# Upgrade 1350 — Cash receipt anomaly flags

Improves the read-only, permission-gated receipt diagnostic to detect NULL payment references, duplicate non-NULL references, and nonpositive/NULL receipt amounts. Uses numeric aggregation to avoid bigint sum overflow. Does not enable motel/Pending Payment collection, alter existing payment writes, or claim settlement verification.

## Verification
ZIP CRC verified; static SQL assertions checked. No Flutter compilation, live Supabase deployment, or transaction/integration tests performed. Apply to staging first.
