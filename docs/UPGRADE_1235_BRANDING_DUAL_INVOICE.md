# Upgrade 1235 — Company footer and dual invoice template foundation

- The MaterialApp builder now displays the shared company footer across its routes, including section screens, with version/build obtained at runtime from `package_info_plus`. This may need visual layout adjustments for keyboards and small screens.
- Both POS text and structured A4 invoice templates use the **same immutable/read-only invoice document object**. Rendering never posts a payment or creates a second invoice.
- Company footer: `All right reserved for Gelye Sherane Company`, `Powered By Zanyar Sidqi`, installed version.
- Both invoice templates append `Powered By Zanyar Sidqi`.
- The A4 template is a structured document model, **not** a PDF renderer, a printer driver, or government-certified invoice. Company registration, buyer information, taxes and stamping must be configured and checked against local requirements.
- Templates are not yet wired into all existing finance/printing paths. The runtime dependency was added to pubspec; lockfile resolution and Flutter compilation are deferred.
- Live Supabase and physical printer testing are deferred.
