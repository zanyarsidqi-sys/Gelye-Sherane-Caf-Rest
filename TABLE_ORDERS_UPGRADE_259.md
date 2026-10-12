# Upgrade 259 — Customer cart preparation instructions

Adds optional per-product preparation instructions to the customer QR menu cart preview. Instructions can be edited before order submission, appear in the itemized cart review, and clear on refresh along with stale price quotes. No customer name required for normal orders.

**Security/limitations:** UI-only draft; customer order submission remains disabled until authenticated visit-scoped authorization, server-side price enforcement and instruction persistence are implemented. Not Flutter-compiled or live-Supabase-tested.
