# Upgrade 1175 — Mandatory acceptance estimate

On Kitchen `new -> preparing`, the employee must enter a preparation estimate (default example 20 minutes; permitted 1–480). A new authorized Supabase RPC records accepted-by, accepted-at, estimated minutes, and estimated ready timestamp atomically, then invokes the existing status transition. A trigger prevents old clients bypassing the estimate requirement. Kitchen order details show the saved ETA.

**Customer-facing integration is pending:** the database now stores the authoritative estimate, but the public customer status page must still be connected to these fields under customer-scoped access. Do not expose kitchen staff-only rows directly to anonymous visitors.

Flutter compilation and Supabase deployment remain unverified until laptop access.
