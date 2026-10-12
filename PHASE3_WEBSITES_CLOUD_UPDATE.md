# Phase 3 Websites Cloud Settings Update

- Replaced device-local SharedPreferences draft with Supabase-backed settings.
- Reads and updates require active employee and websites_management view/edit permissions, enforced in database RLS.
- Migration: supabase/migrations/20261009_005_website_settings.sql. Apply manually after reviewing schema compatibility.
- Ordering and reservation toggles are planning requests only; they do NOT publish or activate public features.
- No credit management changes were added.
- No Flutter build, database deployment, or device testing was performed. Overall completion remains unverified; prior 54% was only an estimate.
