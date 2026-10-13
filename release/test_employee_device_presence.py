from pathlib import Path

root = Path(__file__).resolve().parents[1]
migration = (root / "supabase/migrations/20261013_1503_employee_device_presence.sql").read_text()
monitor = (root / "lib/shared/employee_device_presence_monitor.dart").read_text()
panel = (root / "lib/shared/employee_devices_panel.dart").read_text()
screen = (root / "lib/sections/security_access_control.dart").read_text()
app = (root / "lib/app/cafe_app.dart").read_text()

assert "enable row level security" in migration
assert "revoke all on public.gs_employee_device_presence from public, anon, authenticated" in migration
assert "coalesce(auth.jwt() ->> 'aal', '') = 'aal2'" in migration
assert "lower(btrim(coalesce(employee.role, ''))) in ('owner', 'manager')" in migration
assert "security_access_control', p_action" in migration
assert "interval '2 minutes'" in migration
assert "can_revoke" in migration and "bool_or" in migration
assert "p_session_id = nullif(auth.jwt() ->> 'session_id', '')::uuid" in migration
assert "not (user_id = auth.uid() and session_id = v_current_session)" in migration
assert "gs_employee_device_heartbeat" in monitor
assert "Duration(seconds: 30)" in monitor
assert "SignOutScope.local" in monitor
assert "gs_revoke_employee_device" in panel
assert "gs_revoke_other_online_employee_devices" in panel
assert "Duration(seconds: 30)" in panel
assert "device.revoked_at is not null" in migration
assert "current_session_preserved', true" in migration
assert "gs_system_audit_events" in migration
assert "authorizedContent: EmployeeDevicesPanel()" in screen
assert "EmployeeDevicePresenceMonitor(" in app

print("Owner/manager employee-device presence and revocation contract: PASS")
