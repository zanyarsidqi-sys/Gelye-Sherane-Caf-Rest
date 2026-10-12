# Upgrade 1143 — Kitchen handover concurrency guard

The previous migration locked the order parent row, which blocks concurrent child INSERTs through FK locking, but does **not** necessarily block UPDATEs to existing item prices or quantities. This migration additionally locks the current order-item rows with `FOR UPDATE` before validating and changing an order to `served`. Invalid or empty item sets remain rejected; employee permissions and valid transitions are preserved. RPC EXECUTE is revoked from PUBLIC and anon, then granted to authenticated.

Static regression tests only. Migration not deployed; live transaction/concurrency tests and Flutter compilation remain outstanding. Section 05 live acceptance: 0/5 verified; overall functional completion unknown.
