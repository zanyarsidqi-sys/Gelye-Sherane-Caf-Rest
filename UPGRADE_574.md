# Upgrade 574 — Bind kitchen dispatch evidence to the exact replacement receipt

Security and correctness fix: the receipt kitchen-status RPC now validates that the revision event belongs to the receipt’s exact order item and replacement product before reading its dispatches. A mismatch returns `revision_receipt_mismatch` and never claims kitchen acknowledgment. The existing authenticated employee receipt ownership and kitchen/table view permissions remain enforced. This migration replaces the existing function without changing its signature.

Apply migration 574 after 573. Static checks do not replace live Supabase migration, RLS, Flutter compilation, or kitchen workflow testing.
