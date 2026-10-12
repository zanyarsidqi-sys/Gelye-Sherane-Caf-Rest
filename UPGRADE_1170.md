# Upgrade 1170 — Kitchen terminal-order integrity

Cross-section review identified that the item guard introduced in 1144
protected served orders but not cancelled orders. This migration extends
parent-row locking and item immutability to both terminal statuses. The
existing trigger stays attached and invokes the replaced function.

Static tests only. Supabase staging deployment and Flutter compilation
remain deferred until laptop verification. This is not production sign-off.
