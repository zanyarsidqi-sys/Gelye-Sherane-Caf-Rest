from pathlib import Path

root = Path(__file__).resolve().parents[1]
app = (root / "lib/app/cafe_app.dart").read_text()
manifest = (root / "web/manifest.json").read_text()
index = (root / "web/index.html").read_text()
workflow = (
    root / ".github/workflows/validate-1.0.0.8-workspace.yml"
).read_text()

brand = "Gelye Sherane Cafè & Rest"
assert f"label: '{brand}'" in app
assert f"title: '{brand}'" in app
assert f"'{brand}'" in app
assert "Cafê" not in app
assert f'"name": "{brand}"' in manifest
assert f'"short_name": "Cafè & Rest"' in manifest
assert "Gelye Sherane Cafè &amp; Rest" in index

# Shortcuts and the section list must remain derived from the current
# authorized-section set; this is a presentation update, not a permission change.
assert "selected.where((section) => section.id == id)" in app
assert "for (final section in filtered)" in app
assert "maxWidth: 1120" in app
assert "GelyeProfessionalTheme.navySoft" in app
assert "GelyeProfessionalTheme.gold" in app
assert "staging/release-1.0.0.8-workspace" in workflow
assert 'APP_RELEASE_VERSION=1.0.0.8' in workflow

print("Employee workspace branding and responsive layout contract: PASS")
