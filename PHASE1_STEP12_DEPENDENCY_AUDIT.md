# Phase 1 Step 12 — SQL dependency audit (Rest)

This is a **static, conservative scan**, not a database execution or proof of SQL validity.

- Migration entries: 475
- SHA-256 matches: 475
- Missing source files: 0
- Modified source files: 0
- Foreign-key references to tables created later (candidates): 0
- ALTER TABLE / CREATE INDEX targets created later (candidates): 0

Candidate findings are included in the JSON report. Regex scanning can produce false positives and miss dynamic SQL, views, functions, triggers, schemas, and conditional dependencies. **Do not deploy** the proposed rename plan without isolated database execution and review of actual migration history. No original SQL files were modified.
