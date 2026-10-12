# Upgrade 1371: Dashboard recorded-cash filter

The existing Dashboard Cash Reconciliation list now filters its authorized RPC rows by recorded cash amount: all, positive recorded cash, exactly zero cash, or invalid/unavailable amount. The same filtered list drives displayed rows and the **bottom-of-list** cash total/count. This does not infer overall settlement, credit or electronic status. The existing server-authorized order detail/attestation workflows are unchanged. No invoice printing or saving has been enabled.

Verification: archive CRC, preservation of original entries and static source assertions. Flutter compilation and live Supabase/RLS testing remain pending.
