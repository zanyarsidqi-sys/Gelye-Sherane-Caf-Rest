from pathlib import Path
p=Path(__file__).resolve().parents[1]/'lib/app/cafe_app.dart'
s=p.read_text()
checks={
 'opening employee initialized':'_openingEmployeeId = Supabase.instance.client.auth.currentUser?.id;' in s,
 'initial employee enforced':'userAtStart != _openingEmployeeId' in s,
 'async employee enforced':'userAtStart == _openingEmployeeId' in s,
 'auth change employee enforced':'state.session?.user.id != _openingEmployeeId' in s,
 'dashboard navigation awaited':s.count('await Navigator.of(context).push<void>(')==2,
 'terminated route does not requeue':'if (mounted && _verificationQueued && !_sessionTerminated)' in s,
}
for name,ok in checks.items():print(('PASS' if ok else 'FAIL'),name)
raise SystemExit(0 if all(checks.values()) else 1)
