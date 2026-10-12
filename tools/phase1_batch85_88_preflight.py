#!/usr/bin/env python3
"""Offline Flutter structural preflight; NOT a Dart compiler."""
import pathlib,re,json,sys
root=pathlib.Path(__file__).resolve().parents[1]
source=(root/'lib/app/cafe_app.dart').read_text()
checks={}
checks['theme_updates_immediately']=source.index('_selectedThemeMode = newValue ? ThemeMode.dark : ThemeMode.light;') < source.index('final preferences = await SharedPreferences.getInstance();',source.index('Future<void> _toggleTheme()'))
checks['toggle_epoch_guard']='changeEpoch != _appearanceChangeEpoch' in source
checks['load_epoch_guard']='loadEpoch == _appearanceChangeEpoch' in source
missing=[]
files=list((root/'lib').rglob('*.dart'))
for file in files:
 for imp in re.findall(r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]",file.read_text(),re.M):
  if imp.startswith('package:'):
   package,_,relative=imp[8:].partition('/')
   if package==root.name and not (root/'lib'/relative).exists():missing.append(str(file.relative_to(root))+': '+imp)
  elif not imp.startswith(('dart:','package:')) and not (file.parent/imp).exists():missing.append(str(file.relative_to(root))+': '+imp)
checks['local_imports_resolve']=not missing
checks['pubspec_exists']=(root/'pubspec.yaml').is_file()
checks['web_scaffold_exists']=(root/'web').is_dir()
platforms={p:(root/p).is_dir() for p in ('android','ios','windows','web')}
print(json.dumps({'checks':checks,'missing_imports':missing,'platform_scaffolds':platforms,'dart_files':len(files)},indent=2))
sys.exit(0 if all(checks.values()) else 1)
