# Credit posting: invoice-row serialization — Upgrade 1453

The journal charge trigger now locks the source motel invoice **FOR UPDATE** before testing for existing cash or credit settlement. This closes a race in which different credit verification requests could both pass a shared-lock existence check before either inserts a journal row.

Run static regression: `python3 tests/financial_credit_source_regression_1453.py` from the project root. These 20 assertions only verify source presence.

Staging tests still required: two distinct request IDs on one invoice in separate connections; same request/same idempotency key retry; different idempotency key rejection; cash versus credit race; rollback after journal trigger exception; journal/account balance; RLS/definer privileges; deadlock timeout and lock ordering. No live staging connection supplied.

Do not treat a journal charge as a settled invoice or a certified Dashboard amount.
