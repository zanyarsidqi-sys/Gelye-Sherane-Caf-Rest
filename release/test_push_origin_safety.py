from pathlib import Path
s = (Path(__file__).resolve().parents[1]/'web/push_client.js').read_text()
assert 'url.username || url.password || url.pathname' in s
assert 'url.search || url.hash' in s
assert 'workerURL.origin !== location.origin' in s
assert 'new URL(scope).origin !== location.origin' in s
print('Push endpoint and worker origin guards: PASS')
