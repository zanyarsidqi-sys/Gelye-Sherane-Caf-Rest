# Upgrade 537 — Server-side replacement product search

- Replaced the fixed 500-product preload with a bounded Supabase search RPC.
- Searches active menu products by name or barcode; returns at most 50 matches.
- Requests are sequenced so late responses cannot overwrite newer searches.
- Product selection is cleared while a new search runs; submission disabled until results return.
- Requires authenticated Table Orders edit permission. The replacement transaction continues to set prices and enforce financial/kitchen guards on the server.

## Deployment and limitations
Apply migration `20261010_537_replacement_catalog_search.sql` after 535, then rebuild the Flutter app. Search results are limited to 50; refine the query to locate products outside the first page. Flutter compile and live Supabase deployment have not been performed. Confirm SQL `ESCAPE` behavior and the schema types on staging before production.
