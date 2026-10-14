from pathlib import Path

root = Path(__file__).resolve().parents[1]
app = (root / "lib/app/cafe_app.dart").read_text()
dashboard = (root / "lib/screens/dashboard/dashboard_screen.dart").read_text()
public_landing = (root / "lib/shared/public_landing_page.dart").read_text()

# All branded footers are removed from the app shell, public site, and
# dashboard. The dashboard itself remains scrollable and interactive.
for source in (app, dashboard, public_landing):
    assert "GelyeCompanyFooter" not in source
    assert "All Rights Reserved for Gelye Sherane Café & Rest" not in source
    assert "Powered by Zanyar Sidqi" not in source
assert "_CafeFooterRouteObserver" not in app
assert "showGlobalFooter" not in app
assert "_websiteFooter" not in public_landing
assert "return RefreshIndicator(" in dashboard
assert "child: ListView(" in dashboard

print("App, dashboard, and public-site footer removal: PASS")
