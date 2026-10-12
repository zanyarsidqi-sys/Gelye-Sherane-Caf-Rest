from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'lib/auth/auth_gate.dart').read_text()
assert 'void initState()' in s and '_restoreRememberedDevice();' in s
assert 'DeviceSessionPreference.allows(session)' in s
assert 'auth.getUser()' in s
assert 'AuthenticatorAssuranceLevels.aal2' in s
assert 'await _handleMfaVerified();' in s
assert '_permissionService.getAllowedSections()' in s
print('Saved-device restoration source contract: PASS')
