# Phase 3 Batch 7 — Secure order backend foundation (opt-in)

This batch adds an OPTIONAL SQL migration and a Dart RPC client, without
changing existing login, section screens, preview state, or existing database.

Migration: supabase/migrations/20261009_001_phase3_order_foundation.sql
Service: lib/services/secure_order_service.dart

Features:
- Separate normal/tourism prices on one product barcode.
- Motel orders always use tourism prices (database CHECK + RPC).
- Orders capture the actual server-calculated unit price.
- Authenticated employee and per-section can_create checks at database layer.
- No direct client write policies for order tables.
- Separate gs_ tables to avoid overwriting existing business tables.

DO NOT apply SQL blindly. Confirm your employee_profiles / employee_section_permissions
schema and section keys ('menu', 'table_orders', 'motel_orders', 'kitchen').
Do not switch live ordering to this RPC until product administration,
order status permissions, and end-to-end security tests are implemented.

Current app still uses temporary in-memory previews. This migration has NOT
been deployed to your Supabase account. No Flutter compilation performed here.

Windows: flutter pub get && flutter analyze && flutter test && flutter run -d chrome
Progress: estimated 19% implementation; 0/35 production-verified sections.
