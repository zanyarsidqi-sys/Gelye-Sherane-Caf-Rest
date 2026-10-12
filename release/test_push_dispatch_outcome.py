from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'supabase/functions/browser-push/index.ts').read_text()
assert "return 'expired'" in s and "return 'accepted'" in s
assert "const outcome=rows.length ? await send" in s
assert "status:deliveryStatus(outcome)" in s and "from './dispatch_policy.mjs'" in s
assert "status:rows.length?'sent':'failed'" not in s
assert "deliveryDecision({eligible,subscriptionPresent:rows.length>0,releaseEvent:true,publishedRelease:releases.length>0})==='failed'" in s
print('PASS: expired/missing Web Push subscriptions cannot be recorded as delivered')
