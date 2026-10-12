from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'lib/app/cafe_app.dart').read_text()
start=s.index('Future<void> _restoreSavedSession()')
end=s.index('void _openStaffEntrance(',start)
body=s[start:end]
assert 'sessionBefore = DeviceSessionPreference.sessionId(authBefore.currentSession)' in body
assert 'sessionBefore != null' in body
assert 'DeviceSessionPreference.sessionId(auth.currentSession) == sessionBefore' in body
print('Restore session identity guard: PASS')
