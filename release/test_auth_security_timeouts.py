from pathlib import Path
import re


auth_gate = Path("lib/auth/auth_gate.dart").read_text(encoding="utf-8")
employee_login = Path("lib/auth/employee_login_screen.dart").read_text(encoding="utf-8")
permissions = Path("lib/services/employee_permission_service.dart").read_text(
    encoding="utf-8"
)
saved_session = Path("lib/services/saved_session_service.dart").read_text(
    encoding="utf-8"
)

assert "static const _securityTimeout = Duration(seconds: 12)" in auth_gate
assert "auth.getUser().timeout(_securityTimeout)" in auth_gate
assert "DeviceSessionPreference.allows(" in auth_gate
assert ").timeout(_securityTimeout))" in auth_gate
assert "Could not verify the saved employee session. Please sign in again." in auth_gate
assert "_AuthStep.verificationRetry" in auth_gate
assert "Retry security check" in auth_gate
assert "Your verified session is still protected." in auth_gate
mfa_screen = Path("lib/auth/mfa_screen.dart").read_text(encoding="utf-8")
assert ".getActiveEmployee()" in auth_gate
assert ".getAllowedSections()" in auth_gate
assert auth_gate.count(".timeout(_securityTimeout)") >= 4
assert "static const _mfaRequestTimeout = Duration(seconds: 15)" in mfa_screen
assert re.search(
    r"\.listFactors\(\)\s*\.timeout\(_mfaRequestTimeout\)", mfa_screen
)
assert re.search(
    r"\.challengeAndVerify\([\s\S]*?\)\s*\.timeout\(_mfaRequestTimeout\)",
    mfa_screen,
)
assert "Retry MFA check" in mfa_screen
assert "unawaited(_clearUnverifiedDevicePreference())" in auth_gate
assert "_clearUnverifiedDevicePreference" in auth_gate
assert "_step = _AuthStep.login" in auth_gate
assert "DeviceSessionPreference.clear().timeout(_cleanupTimeout)" in auth_gate
assert "signOut(scope: SignOutScope.local)\n          .timeout(_cleanupTimeout)" in auth_gate

assert "signInWithPassword(" in employee_login
assert ").timeout(_requestTimeout);" in employee_login
assert "DeviceSessionPreference.save(" in employee_login
assert ").timeout(_requestTimeout);" in employee_login
assert "DeviceSessionPreference.allows(" in permissions
assert ").timeout(_requestTimeout))" in permissions
assert "DeviceSessionPreference.allows(" in saved_session
assert ").timeout(_requestTimeout))" in saved_session

print("Employee sign-in and MFA checks exit loading state on timeout: PASS")
