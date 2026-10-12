# Steps 141–144

- Require positive integer order_id in claimed print job before resolver/printer
- Always compare resolved ticket orderId against claimed orderId
- Add 3 Dart regression tests for missing, noninteger, and mismatched order IDs
- Add runnable offline preflight and preserve existing migration files

Dart tests and live Supabase remain unverified.
