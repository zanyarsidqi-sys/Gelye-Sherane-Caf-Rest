# Upgrade 1144 — Kitchen served-item immutability

Adds a PostgreSQL trigger on `gs_order_items` to reject inserts, updates and deletes after an order is served. It also prohibits reassigning an item to another order. The trigger acquires the parent order row lock used by the kitchen handover RPC, serializing writes with handover and preserving the final item snapshot used by stock consumption and invoicing.

**Important:** Trigger-level locking can introduce deadlocks in concurrent operations that lock child rows first; test staging concurrency and ordering before production deployment. Migration has not been applied. Existing application behavior, Flutter compilation, and live Supabase workflows remain unverified.

Section 05: 4/4 source components identified; 0/5 runtime acceptance areas verified; functional completion unknown.
