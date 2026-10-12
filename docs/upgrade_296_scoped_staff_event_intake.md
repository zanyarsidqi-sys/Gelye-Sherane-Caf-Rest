# Upgrade 296 — Scoped staff event intake
- Employee can choose whole venue or one/multiple tables, with combined seating-capacity feedback.
- New RPC atomically creates event, advance product requests, venue scope and selected-table assignments.
- Available table RPC excludes approved overlapping events (including whole venue) and ordinary reservations.
- Admin approval still required; no kitchen tickets or payments are created on request.
- Live database migration and Flutter compilation have NOT been performed. Approval and booking trigger interactions require integration tests.
- Public event submission remains disabled until CAPTCHA and rate limiting are deployed.
