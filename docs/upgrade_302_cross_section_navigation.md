# Upgrade 302 — Table Orders cross-section navigation

Added responsive quick links from staff Table Orders to Tables, Kitchen, Menu and Customers. Each destination is the existing section screen with its existing SectionShell authorization and Supabase permission checks. No direct data access or bypass is introduced by these links.

## Integration review
- Tables → Table Orders: navigation connected; existing table assignment and order persistence still need real-device end-to-end tests.
- Table Orders → Kitchen: navigation connected; the existing live kitchen queue must be verified against order creation, station tickets and status changes.
- Table Orders → Menu: navigation connected; tourism/normal pricing and barcode resolution must be verified server-side.
- Table Orders → Customers: navigation connected; customer identity and order/visit linkage must be verified.
- Payments: deliberately not linked yet because the InvoicesPaymentsScreen is currently a standalone Scaffold without SectionShell; permission-safe navigation needs review first.
- Public event submissions: pending Turnstile widget and live testing; no claim of customer-facing completion.

No Flutter SDK is available in this build environment; compilation and live Supabase deployment are NOT verified. Before moving to Section 04, generate iPhone and Windows design mockups for user approval, then correct and test integration issues.
