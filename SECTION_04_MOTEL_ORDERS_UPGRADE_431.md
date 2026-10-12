# Upgrade 431 — Customer Authentication Binding Foundation

Adds a locked-down mapping between a Supabase-authenticated user and a credit customer. Only independently verified bindings qualify, with unique verified customer and user mappings, verification evidence metadata and a customer read-only status RPC. No staff or customer RPC can create/approve bindings yet: verification requires a separately designed, auditable identity-onboarding process. This upgrade does **not** capture consent or authorize any credit payment.

Migration: `20261010_431_credit_customer_auth_binding_foundation.sql`. Flutter compilation and live Supabase testing not performed.
