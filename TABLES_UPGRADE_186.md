# Tables Upgrade 186 — Item fulfillment transitions

Added backend-validated, row-locked, sequential transitions for table items:
not accepted → accepted → preparing → prepared → picked up → delivered.
Each change records the authenticated actor and time in a locked-down
fulfillment event log. Flutter Tables now shows a next-step action per
item in the existing Items & Money dialog and reloads after success.

**Limitations:** This treats each order-item row as one fulfillment unit,
not individual quantities; partial deliveries are not supported. The
backend permits staff with Tables, Table Orders, or Kitchen edit access,
but finer-grained department permissions remain to be designed.
No push notifications or realtime delivery yet; event history provides
the foundation for notification dispatch. No financial transactions are
created and delivery does not mean paid.

Tables **63% estimated**. Source ZIP integrity checked; no Flutter
compilation or live Supabase migration/test executed.
