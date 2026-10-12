# Upgrade 1378: Source-aligned Cash Reconciliation row details

- Render receipt counts using the same nonnegative integer validation as the filter, showing Unavailable for malformed values.
- Show tap-to-inspect instruction only for valid positive integer order IDs; otherwise explain why financial review is unavailable.
- Preserve original Flutter Material layout, search, three dropdown filters, and bottom-of-list cash total.
- No changes to RPC authorization, payment attestation, official invoice printing, or saving.
- ZIP CRC and original-path preservation tested; Flutter compile, live Supabase, screenshot comparison remain unverified.
