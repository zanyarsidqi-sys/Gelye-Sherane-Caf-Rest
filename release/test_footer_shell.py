from pathlib import Path
r=Path(__file__).resolve().parents[1]
a=(r/'lib/app/cafe_app.dart').read_text()
assert a.count('GelyeCompanyFooter(version: _installedVersion)')==1
assert '_CafeFooterBoundary' not in a
assert 'AppReleaseVersion.label' in a
print('Footer shell static checks: PASS')
