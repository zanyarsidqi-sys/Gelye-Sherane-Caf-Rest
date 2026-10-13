from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'.github/workflows/validate-1.0.0.3-dashboard.yml').read_text()
assert s.index('Compile Flutter web with candidate version') < s.index('Upload staging artifact')
assert 'uses: actions/upload-artifact@v4' in s
assert 'path: build/web/' in s
assert 'if-no-files-found: error' in s
assert '--dart-define="APP_RELEASE_VERSION=$RELEASE_VERSION"' in s
assert 'staging/release-1.0.0.3-dashboard' in s
assert 'environment:' not in s, 'Staging validation must not configure production deployment'
print('CI staging artifact contract: PASS')
