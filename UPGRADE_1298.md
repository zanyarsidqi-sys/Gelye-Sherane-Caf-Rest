# Dashboard Upgrade 1298

Scope: Section 01 Dashboard only.

The seven-day weekly RPC cash_iqd validator now rejects fractional IQD values, which previously would be silently truncated by the existing whole-dinar formatter. Valid signed integer amounts and null/omitted permission-filtered values are retained.

Validation: ZIP CRC and preservation of all unrelated entries, source assertion. Flutter compile, Supabase and device testing not run (SDK and credentials unavailable).
