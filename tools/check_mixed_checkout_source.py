#!/usr/bin/env python3
"""Source-only checkout regression checks. No database access required."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
M = ROOT / "supabase" / "migrations"
issues = []
def read(suffix):
    matches = list(M.glob("*_" + suffix + ".sql"))
    if len(matches) != 1:
        issues.append(f"Expected one migration *_{suffix}.sql; found {len(matches)}")
        return ""
    return matches[0].read_text(encoding="utf-8")

intake = read("130_trusted_provider_event_intake")
posting = read("131_verified_provider_ledger_posting")
dedup = read("132_provider_transaction_dedup")
attest = read("133_mixed_payment_finance_attestation")
guards = read("139_attestation_conflict_guards")
release = read("141_reapply_hardened_mixed_release")
preflight = read("136_mixed_visit_checkout_preflight")
diagnostics = read("144_mixed_checkout_deployment_diagnostics")

checks = [
 ("provider intake restricted", "auth.role()" in intake and "service_role" in intake),
 ("intake checks amount and reference", "v_evidence.amount_iqd" in intake and "v_evidence.external_reference" in intake),
 ("posting restricted", "auth.role()" in posting and "service_role" in posting),
 ("posting uses idempotent ledger reference", "source_reference=p_inbox_id::text" in posting),
 ("provider dedup migration present", bool(dedup)),
 ("mixed settlement requires MFA", "'aal2'" in attest),
 ("mixed settlement checks verified inbox", "verified_by_server" in attest),
 ("conflicting attestations trigger", "gs_reject_conflicting_mixed_attestation" in guards and "gs_reject_conflicting_cash_attestation" in guards),
 ("release feature gated", "gs_mixed_checkout_feature_gate" in release and "not exists" in release),
 ("release checks physical tasks", "gs_visit_physical_checkout_status" in release),
 ("release recalculates mixed totals", "v_provider<>v_a.verified_provider_iqd" in release),
 ("release rejects unverified evidence", "Unverified, unaccounted or corrected" in release),
 ("read-only preflight exists", "gs_mixed_visit_checkout_preflight" in preflight),
 ("deployment diagnostics exists", "gs_mixed_checkout_deployment_diagnostics" in diagnostics),
]
for label, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {label}")
    if not ok: issues.append(label)

# Migration immutability: the hardened release must be an additive migration
# when an earlier release migration has already been applied.
if release.strip() == read("137_guarded_mixed_table_release").strip():
    print("NOTE: release migration 141 duplicates 137 source; inspect applied migration history.")
else:
    print("NOTE: compare release migrations 137 and 141 against applied history.")

# Source tests cannot establish signatures, types, RLS runtime behavior,
# transaction isolation or provider API authenticity.
print("SOURCE CHECK ONLY — NOT A DATABASE OR PAYMENT INTEGRATION TEST")
sys.exit(1 if issues else 0)
