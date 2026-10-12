# Web Push preflight upgrade
- Validate Supabase endpoint and required authentication before requesting browser notification permission or registering a worker.
- Test that invalid endpoint and missing credentials produce no browser-side changes.
- 15 Node Web Push tests passed locally. This does not establish live delivery or release readiness.
