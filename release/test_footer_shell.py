from pathlib import Path
r=Path(__file__).resolve().parents[1]
a=(r/'lib/app/cafe_app.dart').read_text()
dashboard=(r/'lib/screens/dashboard/dashboard_screen.dart').read_text()
public_site=(r/'lib/shared/public_landing_page.dart').read_text()
invoice=(r/'lib/shared/gelye_invoice_templates.dart').read_text()
official_invoice=(r/'lib/shared/gelye_official_invoice_layout.dart').read_text()
station_print=(r/'lib/services/station_print_worker.dart').read_text()
for source in (a, dashboard, public_site, invoice, official_invoice, station_print):
    assert 'All Rights Reserved for Gelye Sherane Café & Rest' not in source
    assert 'Powered by Zanyar Sidqi' not in source
    assert 'Powered By Zanyar Sidqi' not in source
assert 'GelyeCompanyFooter' not in a
assert 'gelyeBillPoweredBy' not in invoice
assert "static const footer=" not in official_invoice
assert 'Powered By Zanyar Sidqi' not in station_print
print('Project footer removal checks: PASS')
