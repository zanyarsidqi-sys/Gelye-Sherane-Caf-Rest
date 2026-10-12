# Web Push release gate — 1.0.0.2

Status: **NOT READY / NOT DEPLOYED**.

Run `python3 tools/check_web_push_release.py` to verify required files are present. This is not a live delivery test.

Before release: validate and apply reviewed SQL in staging then production; configure VAPID/dispatch secrets; deploy Edge Function; configure scheduled dispatch; build Flutter web with public VAPID key; deploy site; verify footer and web service worker; test iPhone Home Screen push while backgrounded; confirm published-release alert and no draft alert; obtain owner approval. Never store private keys in repository.
