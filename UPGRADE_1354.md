# Upgrade 1354 — Explainable invoice finance review

Adds deterministic, machine-readable review reason codes and a reason count to the existing permission-protected, read-only motel invoice diagnostic. This lets authorized finance screens show why an invoice is blocked (invalid totals, mismatched lines, ambiguous cash settlement, or payment-status mismatch). Existing permission checks and `collection_authorized=false` are retained. This upgrade does **not** enable or execute payments, and does not change Standing Cash collection logic.

Verification: ZIP CRC, SQL source assertions, and regression contract checks. Live Supabase migrations and Flutter builds were not run.
