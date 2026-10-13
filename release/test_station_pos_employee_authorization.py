from pathlib import Path
import re


app = Path("lib/app/cafe_app.dart").read_text(encoding="utf-8")
auth_gate = Path("lib/auth/auth_gate.dart").read_text(encoding="utf-8")
station_gate = Path("lib/shared/station_device_gate.dart").read_text(encoding="utf-8")
station_login = Path("lib/shared/station_pos_login_screen.dart").read_text(encoding="utf-8")

assert "onStationPos: () => _openStationPos(homeContext)" in app
match = re.search(
    r"void _openStationPos\(BuildContext context\)\s*\{(?P<body>.*?)\n  \}",
    app,
    re.DOTALL,
)
assert match, "Station POS must enter through its employee authorization route."
route = match.group("body")
assert "AuthGate(" in route
assert route.index("AuthGate(") < route.index("onAuthorized:")
assert route.index("onAuthorized:") < route.index("StationDeviceGate(")
assert "AuthenticatorAssuranceLevels.aal2" in route
assert "authorizedEmployeeUserId: userId" in route
assert "authorizedEmployeeSessionId: employeeSessionId" in route
assert "pushReplacement" in route

for required_check in (
    "MFA assurance level",
    "active employee profile (RLS)",
    "section permissions (RLS)",
):
    assert required_check in auth_gate, f"AuthGate must retain {required_check}."

assert "StationPosLoginScreen(onAuthenticated:" in station_gate
assert "onAuthStateChange.listen" in station_gate
assert "_lockAfterEmployeeAuthorizationLost()" in station_gate
assert "StationDeviceSessionService().signIn" in station_login
assert "Station username" in station_login
assert "Station password" in station_login

print(
    "Station POS employee MFA authorization and separate station credentials: PASS"
)
