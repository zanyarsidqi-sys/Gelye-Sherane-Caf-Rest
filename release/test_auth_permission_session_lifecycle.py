from pathlib import Path

root = Path(__file__).resolve().parents[1]
auth_gate = (root / "lib/auth/auth_gate.dart").read_text(encoding="utf-8")
app = (root / "lib/app/cafe_app.dart").read_text(encoding="utf-8")
permissions = (
    root / "lib/services/employee_permission_service.dart"
).read_text(encoding="utf-8")
staging_workflow = (
    root / ".github/workflows/validate-1.0.0.10-auth.yml"
).read_text(encoding="utf-8")

assert (
    "final Future<void> Function(Set<String> allowedSections) onAuthorized"
    in auth_gate
)
assert "await widget.onAuthorized(allowedSections);" in auth_gate
assert (
    "final expectedSessionId = DeviceSessionPreference.sessionId(expected);"
    in permissions
)
assert "DeviceSessionPreference.sessionId(current) != expectedSessionId" in permissions
assert "current.accessToken != expected.accessToken" not in permissions

assert "_openingEmployeeSessionId" in app
assert "_managementLifecycleVisible" in app
assert "state == AppLifecycleState.inactive" in app
assert "Retry employee check" in app
assert "Return to staff sign-in" in app
assert (
    "Employee access could not be verified. Check your connection and retry."
    in app
)

listener_start = app.index(
    "_authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen"
)
auth_listener = app[
    listener_start : app.index("_accessReviewTimer = Timer.periodic", listener_start)
]
assert "_authorizationEpoch++;" in auth_listener
assert "Token refreshes retain the same Supabase session identity." in auth_listener
assert "invalidate an in-flight RLS review" in auth_listener

check_start = app.index("Future<void> _checkAccess(")
review = app[check_start : app.index("Future<void> _logout()", check_start)]
assert "if (!sameEmployeeSession || !permissionStillValid)" in review
assert "if (reviewEpoch != _authorizationEpoch || !_managementLifecycleVisible)" in review
assert "EMPLOYEE ACCESS REVIEW FAILED:" in review

assert "--dart-define-from-file=config/supabase.public.json" not in staging_workflow
assert "STAGING_SUPABASE_URL" in staging_workflow
assert "STAGING_SUPABASE_EXPECTED_PROJECT_REF" in staging_workflow
assert "STAGING_SUPABASE_ANON_KEY" in staging_workflow
assert 'STAGING_SUPABASE_EXPECTED_PROJECT_REF" != "$PRODUCTION_SUPABASE_EXPECTED_PROJECT_REF"' in staging_workflow
assert staging_workflow.count(
    "if: steps.staging_config.outputs.available == 'true'"
) == 3
assert "No artifact was built because the only configured Supabase project is production." in staging_workflow

print("Employee session refresh and retry behavior: PASS")
print("Staging build isolation gate: PASS")
