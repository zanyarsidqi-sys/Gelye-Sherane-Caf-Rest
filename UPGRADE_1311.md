Upgrade 1311 — Dashboard cash card + linked Payments Management integration

Dashboard: rename card to Recorded cash collected and explicitly identify it as cash-only, not total revenue.
Linked Payments Management: label the 200-order ledger sample clearly, avoiding misleading comparison with the date-filtered Dashboard; sanitize backend errors; correct the receipt brand for the project.
No change to Supabase permissions, financial posting, payment calculations, or other management sections.
Verification: ZIP integrity, changed-source assertions, preservation of all previous archive members. Flutter SDK and live Supabase unavailable; device and end-to-end verification pending.
