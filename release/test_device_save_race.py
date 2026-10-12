from pathlib import Path
s = (Path(__file__).resolve().parents[1]/'lib/services/device_session_preference.dart').read_text()
assert 'Session changed while saving device preference' in s
assert 'sessionId(current) != id' in s
assert 'await prefs.remove(_key)' in s
print('Saved device asynchronous account-switch guard: PASS (static)')
