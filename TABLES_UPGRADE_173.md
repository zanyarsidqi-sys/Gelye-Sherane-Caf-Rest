# Tables Upgrade 173 — QR Code Flutter Management

Added a **Table QR** control to each table in Flutter. Authorized staff
retrieve the unique QR token from Upgrade 172's backend, preview a
phone-scannable QR image, copy its HTTPS URL, and regenerate/revoke it
after explicit confirmation.

Requires `--dart-define=CAFE_PUBLIC_MENU_URL=https://your-cafe-site.example`
pointing to the deployed public customer site; if not configured, the
screen does NOT create an invalid QR code. Added `qr_flutter` dependency.

**Not yet implemented:** printable PDF/print button, actual customer
website route `/table`, phone order flow, QR order submission and live
backend validation. Do not print or distribute codes before the customer
website is deployed and tested. Do not assume the URL is configured.

The new requirement for item-level partial payments and payer attribution
remains outstanding, along with full/individual billing and pay/checkout.

Estimated Tables development **53%** (expanded scope). Previous 7/20
major milestone accounting remains unchanged. ZIP integrity verified;
Flutter compilation and live Supabase verification pending.
