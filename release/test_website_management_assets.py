from pathlib import Path

root = Path(__file__).resolve().parents[1]
panel = (root / "lib/shared/website_settings_panel.dart").read_text()
landing = (root / "lib/shared/public_landing_page.dart").read_text()
migration = (
    root / "supabase/migrations/20261013_1504_website_brand_assets.sql"
).read_text().lower()
pubspec = (root / "pubspec.yaml").read_text()
section = (root / "lib/sections/websites_management.dart").read_text()
workflow = (
    root / ".github/workflows/validate-1.0.0.7-orders.yml"
).read_text()

for field in (
    "website_logo_path",
    "website_hero_path",
    "phone",
    "email",
    "address",
    "opening_hours",
):
    assert field in panel, f"Website Management does not edit {field}"

assert "file_picker: ^13.1.0" in pubspec
assert "withdata: true" in panel.lower()
assert "10 * 1024 * 1024" in panel
assert "uploadbinary(" in panel.lower()
assert ".remove(obsoletepaths)" in panel.lower()
assert "cafe-website-assets" in panel
assert "image/jpeg" in migration
assert "image/png" in migration
assert "image/webp" in migration
assert "10485760" in migration
assert "public.cafe_can_manage_website(true)" in migration
assert "gs_public_website_branding" in migration
assert "revoke all on function public.gs_public_website_branding()" in migration
assert "grant execute on function public.gs_public_website_branding()" in migration

# Keep public contact and public image allowlists separate from the full
# employee-protected settings table.
assert "gs_public_website_contact" in landing
assert "gs_public_website_branding" in landing
assert "Powered by Zanyar Sidqi" in landing
assert "cafe_website_settings').select" not in landing
assert "supabase/migrations/20261013_1504_website_brand_assets.sql" in workflow
assert "Expanded(child: TabBarView" in section
assert "WebsiteSettingsPanel()" in section
assert "SingleChildScrollView(child: WebsiteSettingsPanel())" not in section

print("Website photo upload, contact editing, and public footer contract: PASS")
