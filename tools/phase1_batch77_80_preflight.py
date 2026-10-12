from pathlib import Path
import sys
p=Path(__file__).resolve().parents[1]/'lib/app/cafe_app.dart'
t=p.read_text()
app=sys.argv[1]
checks={
'isolated language':f"gelye_cafe_{app}_language_v1" in t,
'isolated favorites':f"cafe_{app}_favorites_v1_$userId" in t,
'isolated appearance':f"cafe_{app}_theme_mode_v2" in t,
'android heartbeat schedule':"if (!_authorized || !_sections.contains('tables') ||\n        kIsWeb || defaultTargetPlatform != TargetPlatform.android".replace('\n','\n') in t,
'favorite identity check':t.count('_authorizedUserId != Supabase.instance.client.auth.currentUser?.id')>=3,
'old shared favorites absent':"'cafe_favorites_v1_$userId'" not in t,
}
for k,v in checks.items(): print(('PASS' if v else 'FAIL'),k)
sys.exit(0 if all(checks.values()) else 1)
