from pathlib import Path

root = Path(__file__).resolve().parents[1]
app = (root / "lib/app/cafe_app.dart").read_text()
dashboard = (root / "lib/screens/dashboard/dashboard_screen.dart").read_text()

assert "static const dashboardRouteName = '/employee-dashboard';" in app
assert "static const publicLandingRouteName = '/public-landing';" in app
assert "navigatorObservers: <NavigatorObserver>[_footerRouteObserver]" in app
assert "name: _CafeFooterRouteObserver.publicLandingRouteName" in app
assert "settings: const RouteSettings(" in app
assert "name: _CafeFooterRouteObserver.dashboardRouteName" in app
assert "if (route is! PageRoute<dynamic>) return;" in app
assert "routeName == publicLandingRouteName" in app
assert "routeName == Navigator.defaultRouteName" in app
assert "rootIsPublicLanding" in app and "!hasCustomerEntryToken" in app
assert "ValueListenableBuilder<bool>(" in app
assert "showFooter" in app and "GelyeCompanyFooter(version: _installedVersion)" in app

# DashboardScreen already includes its own version footer as the last item in
# the scrollable dashboard list; the app-wide fixed footer is hidden on that
# named route to avoid covering the dashboard content. The public landing page
# also owns its scroll-to-bottom footer; customer QR entry routes keep the shell
# footer.
assert "return RefreshIndicator(" in dashboard
assert "child: ListView(" in dashboard
assert "All rights reserved for Gelye Sherane Café & Restaurant" in dashboard
assert "Version ${AppReleaseVersion.label}" in dashboard

print("Dashboard and public-site footer placement: PASS")
