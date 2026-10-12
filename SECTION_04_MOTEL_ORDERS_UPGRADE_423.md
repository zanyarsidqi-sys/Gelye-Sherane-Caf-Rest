# Upgrade 423 — Credit Authorization Invoice Checks

Added a permission-gated read-only RPC and employee **Invoice Checks** button for each authorization request. Checks that the supplied invoice reference is a real motel food finance invoice UUID, requested IQD amount equals invoice total, and invoice remains unpaid. Clearly marks customer identity, consent and charging as unverified/blocked.

This is NOT a customer-facing authorization confirmation and does not enable credit settlement. Staff may still create arbitrary authorization request references; the new check detects but does not prevent them. Next step is enforcing invoice binding at request creation, followed by customer authentication and consent.

Migration: `20261010_423_credit_authorization_invoice_checks.sql`. No live Supabase or Flutter build verification performed.
