#!/usr/bin/env python3
"""Offline regression checks for favorites read/write ordering (not a Dart compiler)."""
from pathlib import Path
import re
s = (Path(__file__).resolve().parents[1] / 'lib/app/cafe_app.dart').read_text()
checks = {
  'load checks generation': 'generation != _favoritesGeneration' in s,
  'toggle invalidates pending read': bool(re.search(r'void _toggleFavorite\(.*?_favoritesGeneration\+\+;\s*setState', s, re.S)),
  'reset invalidates pending read': bool(re.search(r'Future<void> _resetFavorites\(.*?_favoritesGeneration\+\+;\s*setState', s, re.S)),
  'reorder invalidates pending read': bool(re.search(r'void _moveFavorite\(.*?_favoritesGeneration\+\+;\s*setState', s, re.S)),
  'writes remain serialized': '_favoriteWriteTail.then((_) async' in s,
  'reset checks employee after save': bool(re.search(r'await _saveFavorites\(\);\s*if \(!mounted \|\| !_authorized \|\|', s)),
}
for name,ok in checks.items(): print(('PASS' if ok else 'FAIL') + ': ' + name)
assert all(checks.values()), 'Favorites regression preflight failed'
print(f'{len(checks)}/{len(checks)} offline assertions passed')
