# Upgrade 276 - Customer visit session foundation

- Staff-only session issuance, tied to an occupied table and open visit.
- Short-lived opaque tokens; read-only public validity check returns a boolean.
- Sessions automatically revoked when the table is released after checkout.
- No direct anonymous table access, bill access, feedback writes, or order submission.
- Remaining: secure public QR exchange/approval, rate limiting, token handoff,
  privacy review, production testing and integration with customer screens.
- Requires review of the actual table visit schema before deployment.
