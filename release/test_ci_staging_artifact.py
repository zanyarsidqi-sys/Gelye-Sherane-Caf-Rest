from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'.github/workflows/flutter_validation.yml').read_text()
assert s.index('Build web with candidate release version') < s.index('Archive verified web build for staging review')
assert 'uses: actions/upload-artifact@v4' in s
assert 'path: build/web/' in s
assert 'if-no-files-found: error' in s
print('CI staging artifact contract: PASS')
