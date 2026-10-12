from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'supabase/functions/browser-push/index.ts').read_text()
assert "row.endpoint===subscription.endpoint && row.session_id===claims.session_id" in s
assert "if(!sameDevice && existing.length>=10)" in s
assert "method:'PATCH',body:JSON.stringify({p256dh:" in s
assert "id=eq.'+sameDevice.id+'&user_id=eq.'+user.id+'&session_id=eq.'+claims.session_id" in s
print('PASS: existing same-session push subscription is renewed instead of double counted')
