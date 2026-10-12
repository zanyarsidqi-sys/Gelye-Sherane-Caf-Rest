# Upgrade 1138 — Kitchen order amount integrity

- Rejected invalid, negative and fractional line totals in the kitchen order preview instead of silently treating them as zero.
- Accepted nonnegative integer IQD values and numeric strings; summed amounts with exact `BigInt` arithmetic.
- Displayed a clear warning instead of a misleading order total if item data is invalid.
- Source-level regression tests added; Flutter build and live Supabase tests were not run.
- Section 05: five runtime acceptance areas remain unverified.
