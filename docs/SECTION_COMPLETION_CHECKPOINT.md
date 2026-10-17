# Section completion checkpoint — 17 October 2026

Baseline: production a203cb83c37de5a16c45c507296655a7a2821c9c (1.0.4.5). This branch is development only.

## Source inventory

The current navigation registers 25 sections. The union of visible category cards and retained legacy cards contains 727 section/card entries; this is NOT a completion count. Exact names are in section_card_inventory.json. No ten extra sections have been invented to match historical plans.

## Implemented in this batch

- Kitchen Orders: operational order history.
- Kitchen Order Details: actual order items, references, notes and status.
- Kitchen Preparation: preparing-order filter.
- Ready for Delivery: ready-order filter.
- Kitchen Handover: ready orders with the existing served transition.
- Room Orders: motel-source operational orders.
- Ready for Pickup: ready walk-in orders.
- Walk-In Order History: recent walk-in history including cancelled/served orders.
- Order status selector: received, preparing, ready, served and cancelled; completed states request history from the server.
- Staff permission editor uses the same full section card catalog as navigation instead of the incomplete legacy list.

The eight detail views require access to their underlying operational order card. Existing server authorization remains unchanged. No automatic grants, payment changes or stock updates are introduced. Existing executive palette, cards and responsive navigation are preserved.

## Unfinished work

This is not a claim that all sections are operational. Design-preview and generic-record routes remain. Generic records must not be represented as an accounting ledger, stock movement, payroll payment, credit settlement, backup, notification delivery or device operation.

Inventory requires a stock ledger with units, receiving, adjustments and transaction tests. Advanced menu pricing, recipes, scheduling and variants require actual order integration. Customer credit, loyalty and payroll require defined ledgers and settlement rules. Reservations beyond existing table bookings need availability contracts. Marketing and notifications need provider connections and delivery tracking. Device workflows need hardware verification. Backups/restores and offline sync require their own safe integration and recovery verification. Shisha, delivery, feedback and staff operations still include generic record workflows. Report cards must be checked against their actual data sources rather than generic saved notes.

The earlier broad date-range/read-only permission migration was rejected by automatic approval review because it rewrote policies and operational functions with outage/security-regression risk. It was not applied and must not be deployed as-is. Cashier discount and actual per-item split billing remain pending. QR individual bill support is currently a named service request, not automatic splitting.

## Release gates

Flutter analysis, widget tests, and release web build run through the pull-request workflow. No live deployment is requested by this checkpoint. Completion of any remaining card requires implementation of its named behavior, server permission checks, relevant validation and verified results. Do not replace placeholder text alone or route every card to generic notes and call it complete.
