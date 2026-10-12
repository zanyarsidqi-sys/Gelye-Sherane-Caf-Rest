# Upgrade 410 — Authoritative Credit Schema Discovery

Added a permission-gated, read-only PostgreSQL catalog inventory for credit, customer, wallet and account-related public tables/views. It exposes object names, column names/types, and whether row-level security is enabled, but **never account rows, balances or personal data**. The employee finance screen has an **Account Schema** diagnostic button, restricted server-side to Credit Management editors.

This enables identifying the actual existing authoritative account schema before designing a safe debit adapter. A table's presence alone does not verify ownership, balance accuracy, limits or posting support. No debit or settlement is enabled.

Migration: `20261010_410_credit_schema_inventory.sql`. ZIP integrity checked; Flutter build and live Supabase migration not tested.
