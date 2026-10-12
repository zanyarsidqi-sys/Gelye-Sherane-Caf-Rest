# Upgrade 133 — Mixed cash/electronic settlement attestation

Adds a real finance attestation write for fully paid orders containing
server-verified, ledger-posted card/online payments and optional cash.
The finance reviewer must be provisioned, have MFA and financial edit
permission, and cannot attest cash they personally collected.

The SQL checks each electronic ledger credit against verified provider
inbox and original evidence, disallows other ledger postings (except
identical legacy cash mirrors), rejects unverified external evidence,
owner offers, transfers and corrections, and requires exact total
coverage. Attestations are immutable and auditable.

**Not yet table checkout:** release RPC still permits ONLY cash-only
attestations. Additional protections against post-attestation mutation
and visit-wide mixed settlement must be implemented and tested before
mixed-payment checkout is enabled. A real trusted provider API/webhook
integration is also still missing. No Supabase runtime tests performed.
