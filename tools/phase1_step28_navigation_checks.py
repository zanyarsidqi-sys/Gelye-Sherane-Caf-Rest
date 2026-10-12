from pathlib import Path
p=Path(__file__).resolve().parents[1]/'lib/app/cafe_app.dart'
s=p.read_text()
checks={
'lock before navigation':s.index('_lockManagement();',s.index('Future<void> _openSection('))<s.index('await _checkAccess();',s.index('Future<void> _openSection(')),
'busy review blocks navigation':'if (_accessReviewBusy) return; // Existing review will retry on invalidation.' in s,
'logout blocks navigation':'_logoutRecoveryRequired || !_sections.contains(section.id)' in s,
'user binding':'_authorizedUserId != Supabase.instance.client.auth.currentUser?.id' in s,
'signout does not reverify':'if (state.session != null &&' in s,
'background unlock blocked':'WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&' in s,
}
for k,v in checks.items():print(('PASS' if v else 'FAIL'),k)
raise SystemExit(0 if all(checks.values()) else 1)
