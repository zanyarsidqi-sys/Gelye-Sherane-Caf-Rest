#!/usr/bin/env python3
"""Read-only release prerequisite audit; does not access credentials or deploy."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
checks={
 'Web Push browser client':root/'web/push_client.js',
 'Push service worker':root/'web/push/sw.js',
 'Browser push Edge Function':root/'supabase/functions/browser-push/index.ts',
 'Database setup (requires staging validation)':root/'supabase/setup/browser_push.sql',
 'Notifications UI':root/'lib/sections/notifications.dart',
 'Deployment instructions':root/'DEVICE_SESSION_AND_WEB_PUSH_SETUP.md',
}
failed=False
for label,path in checks.items():
 ok=path.is_file() and path.stat().st_size>0
 print(('PASS' if ok else 'FAIL')+' | '+label)
 failed |= not ok
print('NOT VERIFIED: VAPID secrets, SQL applied, deployed Edge Function, cron, Flutter build, live HTTPS hosting, iPhone push receipt.')
print('RELEASE STATUS: NOT READY until live checks pass and owner approves.')
sys.exit(1 if failed else 0)
