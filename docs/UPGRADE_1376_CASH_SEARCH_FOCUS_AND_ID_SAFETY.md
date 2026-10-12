# Upgrade 1376: actual Flutter Cash Reconciliation fidelity and interaction

- Replaced a changing ValueKey / initialValue order search with a persistent TextEditingController, avoiding input focus loss when the first digit is typed.
- Clear filters now clears both controller text and active filter state. Controller is disposed with the widget.
- Financial drill-down validates positive integral order IDs, avoiding accidental truncation of fractional numeric IDs.
- Existing Material UI, authorized RPCs, three filters, read-only financial review, attestation flows and bottom total preserved.
- ZIP CRC and original entry preservation verified; Flutter compile and screenshot similarity not verified.
