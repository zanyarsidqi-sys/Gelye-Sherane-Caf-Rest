# Phase 3 — Staff review queue update
Added authenticated staff queue for public online orders and table reservation requests under Websites Management. New RPCs check websites_management view/edit permissions and lock pending requests during status transitions; audit records capture staff decisions. Deploy migration 009 after migrations 005, 007 and 008.

Unverified: Flutter compilation, deployed SQL, permissions and end-to-end behavior. Reservation approval does not yet enforce table availability or prevent overlapping bookings; staff must verify availability manually. Public submission still needs abuse controls. This is an incremental update, not the completion of Phase 3.

Historical Phase 3 estimate: 54% (unverified). Overall user working estimate: 30% (unverified). Remaining: public protection, capacity rules, operational order acceptance/fulfillment, 35 section implementations and verification, offline sync, platform testing.
