# Upgrade 395 — Verified Payment Source Readiness

Added `gs_staff_check_motel_payment_source(uuid)` to compare payment draft, finance invoice, source reconciliation, and source bridge. The employee finance screen exposes a read-only **Source Readiness** action.

**No payment writer or legacy order mapping is implemented.** The UUID-to-bigint incompatibility remains intentionally blocked. Cash, credit and electronic payment settlement require separately verified backend integration.

Tests: ZIP integrity only. Flutter and live Supabase migrations not executed.
