# Upgrade 1385: both cards discoverable in Payments Management

- Added a source-backed in-panel navigation explanation for Standing Cash and Pending Payment.
- Deep links still focus the requested card first; both cards and cash ledger remain present.
- Added accessible header semantics to both card titles.
- Existing Dashboard/app section routes are not replaced.
- No new payment RPC, permission, or settlement changes. Pending collection remains blocked.
- ZIP and unchanged-entry checks passed; Flutter compile and screenshot comparison not run.
