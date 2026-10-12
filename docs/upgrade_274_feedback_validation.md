# Upgrade 274 - Customer feedback draft validation

The customer feedback screen now validates survey stars, item selection,
and new-product suggestion text locally. It clearly states that drafts are
not sent or saved. No anonymous submission RPC was added.

Security blocker: the existing static table QR token identifies the table,
not the current customer/visit. Before enabling submissions, introduce a
short-lived visit-scoped session with checkout revocation, server-side
rate limiting, and product/table association checks. Do not treat the QR
token alone as proof of authorization.

Flutter compilation and live Supabase tests remain pending.
