# Upgrades 666–685

20 discrete source changes; see the audit JSON and automated source checks. Flutter build and Supabase integration remain unverified.

- 666 | Section 06 | Reject excessively large normal demo prices
- 667 | Section 06 | Reject excessively large tourism demo prices
- 668 | Section 06 | Prevent whitespace-variant duplicate barcodes
- 669 | Section 06 | Normalize barcode search input for demo orders
- 670 | Section 06 | Reject preview names over 200 characters
- 671 | Section 06 | Reject preview barcodes over 100 characters
- 672 | Section 06 | Validate preview name length in form
- 673 | Section 06 | Validate preview barcode length in form
- 674 | Section 06 | Avoid stale local menu search case mismatch
- 675 | Section 06 | Clarify preview form validation limits
- 676 | Section 07 | Reject invalid inventory product identifiers
- 677 | Section 07 | Reject invalid history product identifiers
- 678 | Section 07 | Reject whitespace-only movement reasons
- 679 | Section 07 | Require boolean stock direction before write
- 680 | Section 07 | Reject negative or fractional overview quantities
- 681 | Section 07 | Reject invalid minimum stock values in overview
- 682 | Section 07 | Use exact integer quantities in movement history
- 683 | Section 07 | Flag fractional movement history as unknown
- 684 | Section 07 | Prevent post-session-change inventory success notification
- 685 | Section 07 | Avoid exposing stock-update failure details after employee change
