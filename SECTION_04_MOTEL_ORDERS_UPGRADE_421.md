# Upgrade 421 — Invoice-scoped Customer Authorization Requests

Adds a new staff UI and Supabase request-only workflow to record a proposed customer authorization for a specific invoice reference and exact IQD amount. Pending identity reviews and matching pending barcode links are checked server-side. Each request records the channel, note, requesting employee and timestamp. Duplicate review/invoice/amount combinations are blocked; previous requests can be viewed. **This is not consent**, and no customer-facing authorization or financial posting is implemented. Credit accounts remain pending and payment settlement blocked.

Apply migration `20261010_421_credit_customer_authorization_request.sql` in order. Archive verified; Flutter compilation and live Supabase testing unavailable.
