from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'.github/workflows/validate-1.0.0.2-staging.yml').read_text()
assert s.index('Compile Flutter web') < s.index('Upload staging artifact')
assert 'uses: actions/upload-artifact@v4' in s
assert 'path: build/web/' in s
assert 'if-no-files-found: error' in s
print('CI staging artifact contract: PASS')
