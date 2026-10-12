# Upgrade 584 — Kitchen initialization reliability

Fixed the order of Dart field initialization in `LiveKitchenPanel`: `_statusFilter` is now initialized before `_orders = _load()` begins the initial query. This prevents the initial request from reading a field before initialization. Preserves all existing screens and migrations.

Static regression assertions cover initialization order, server-side status filtering before pagination, and refresh cache clearing. Flutter compilation and live Supabase integration are not verified in this environment.
