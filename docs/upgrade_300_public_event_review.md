# Upgrade 300 — Public event request review and structured products

- Public Flutter event preview now retains structured product names and integer quantities instead of formatted display strings.
- Adds an explicit request review card showing venue scope, selected table count, guests, business model, and product count.
- Highlights insufficient selected seating before submission.
- Provides a local `buildRequestPreview()` map matching the backend field names for future secure submission integration.
- **Public submission remains disabled** because the client still lacks verified CAPTCHA token acquisition, production Edge Function configuration, and end-to-end tests.
- This upgrade is a code change, not a screenshot or a production release.
- Before moving sections: show iPhone/Windows mockups, obtain user corrections, and audit cross-module links.
