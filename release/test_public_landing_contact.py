from pathlib import Path

root = Path(__file__).resolve().parents[1]
page = (root / "lib/shared/public_landing_page.dart").read_text()
shell = (root / "lib/app/cafe_app.dart").read_text()
settings = (root / "lib/shared/website_settings_panel.dart").read_text()
migration = (root / "supabase/migrations/20261013_1502_public_website_contact.sql").read_text().lower()

for callback in ("onOpenMenu", "onReserveTable", "onOrderOnline", "onStaffLogin", "onStationPos"):
    assert callback in page and callback in shell, f"Missing landing action: {callback}"
for label in ("Our menu", "Reservations", "Online ordering", "Contact & hours"):
    assert label in page, f"Missing public landing section: {label}"

for field in ("phone", "email", "address", "opening_hours"):
    assert f"'{field}'" in settings or f".{field}" in settings, f"Missing Website Management field: {field}"
    assert f"add column if not exists {field}" in migration, f"Missing contact migration column: {field}"
    assert f"'{field}'" in migration, f"Missing public contact field: {field}"

assert "gs_public_website_contact" in page
assert "security definer" in migration and "set search_path = ''" in migration
assert "revoke all on function public.gs_public_website_contact() from public, anon, authenticated" in migration
assert "grant execute on function public.gs_public_website_contact() to anon, authenticated" in migration
assert "grant select on public.cafe_website_settings to anon" not in migration
print("Public landing actions and contact-only publication contract: PASS")
