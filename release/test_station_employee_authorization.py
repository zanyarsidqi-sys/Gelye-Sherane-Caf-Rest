from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
app = (ROOT / "lib/app/cafe_app.dart").read_text()
station_gate = (ROOT / "lib/shared/station_device_gate.dart").read_text()
station_service = (
    ROOT / "lib/services/station_device_session_service.dart"
).read_text()
edge = (ROOT / "supabase/functions/station-device-auth/index.ts").read_text()
migration = (
    ROOT
    / "supabase/migrations/20261013_1505_station_employee_authorization.sql"
).read_text()

# Dashboard permission refreshes must not replace a live dashboard with a
# full-screen spinner; failed reviews still take the existing lockout path.
monitor = app[
    app.index("void _startAccessMonitoring()") :
    app.index("void _lockManagement(")
]
assert monitor.count("_checkAccess(showChecking: false)") == 2
access_check = app[
    app.index("Future<void> _checkAccess({bool showChecking = true})") :
    app.index("Future<void> _logout()")
]
assert "if (showChecking)" in access_check
assert "_returnToStaffAuth();" in access_check

# Every Station POS route must start at AuthGate and pass the verified
# employee/session identity into the station screen.
station_route = app[
    app.index("void _openStationPos(") :
    app.index("void _clearRestoredEmployeeAccess(")
]
assert "AuthGate(" in station_route
assert "AuthenticatorAssuranceLevels.aal2" in station_route
assert "authorizedEmployeeUserId: userId" in station_route
assert "authorizedEmployeeSessionId: employeeSessionId" in station_route
assert "StationDeviceGate(" in station_route

# The station screen exits if that exact employee session ends; the server
# also signals explicit employee authorization failures to the client.
assert "authorizedEmployeeSessionId" in station_gate
assert "onAuthStateChange.listen" in station_gate
assert "_lockAfterEmployeeAuthorizationLost()" in station_gate
assert "StationEmployeeAuthorizationException" in station_gate
assert "EMPLOYEE_AUTH_REQUIRED" in station_service

# Edge Function verifies the signed AAL2 employee JWT and binds/checks the
# station token for each action other than revocation-only logout.
assert "auth.getUser(accessToken)" in edge
assert 'claims?.aal !== "aal2"' in edge
assert "gs_1256_employee_can_use_station" in edge
assert "gs_1256_station_employee_session_access" in edge
assert edge.count("authorizeStationSession(tokenHash, employee!)") >= 4
assert 'body.action !== "logout"' in edge

# New database state is additive; no existing session or business record is
# deleted, and unbound sessions can only be claimed by an active AAL2 employee.
assert "add column if not exists employee_user_id uuid" in migration
assert "add column if not exists employee_auth_session_id uuid" in migration
assert "employee_profiles" in migration
assert "employee_section_permissions" in migration
assert "employee_mismatch" in migration
assert "delete from" not in migration.lower()

print("Station employee authorization and dashboard refresh regression checks passed.")
