from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


finance_areas = {
    "cost",
    "revenue",
    "invoices_payments",
    "discount_management",
    "credit_management",
    "payments_management",
}

registry = read("lib/app/section_registry.dart")
registered = re.findall(
    r"CafeSection\(\s*['\"]([^'\"]+)['\"]", registry, re.MULTILINE
)
assert len(registered) == 29 and len(set(registered)) == 29
assert "CafeSection('payments_management', \"Payment Management\"" in registry
assert not (finance_areas - {"payments_management"}).intersection(registered)

hub = read("lib/sections/payments_management.dart")
assert "additionalAccessSectionIds: const [" in hub
for section_id in sorted(finance_areas):
    assert f"'{section_id}'" in hub
assert "DefaultTabController(" in hub and "length: 7" in hub
assert all(
    text in hub
    for text in (
        "CostScreen(compact: true)",
        "RevenueScreen(compact: true)",
        "InvoicesPaymentsScreen(compact: true)",
        "DiscountManagementScreen(compact: true)",
        "CreditManagementScreen(compact: true)",
        "PaymentsReconciliationScreen(",
    )
)
assert "sample amounts and charts in the design reference are not used" in hub

for path, section_id in (
    ("lib/sections/cost.dart", "cost"),
    ("lib/sections/revenue.dart", "revenue"),
    ("lib/sections/invoices_payments.dart", "invoices_payments"),
    ("lib/sections/discount_management.dart", "discount_management"),
    ("lib/sections/credit_management.dart", "credit_management"),
):
    content = read(path)
    assert f"sectionId: '{section_id}'" in content or f'sectionId: "{section_id}"' in content
    assert "compact: compact" in content

reconciliation = read("lib/shared/payments_reconciliation_screen.dart")
assert "sectionId: 'payments_management'" in reconciliation
assert "PaymentsManagementPanel(initialFocus: initialFocus)" in reconciliation

app = read("lib/app/cafe_app.dart")
assert "_financeAreaSectionIds.any(_sections.contains)" in app
assert "PaymentsManagementScreen.tabIndexForSectionId(" in app
assert "id == 'payments_management'" in app

access = read("lib/shared/employee_access_panel.dart")
assert "title: const Text('Payment Management')" in access
assert "authorized finance area(s)" in access

migration_path = ROOT / "supabase/migrations/20261014180000_payment_management_merge.sql"
migration = migration_path.read_text(encoding="utf-8").lower()
assert "delete from public.management_sections" in migration
assert "catalog_count_before <> 34" in migration
assert "catalog_count_after <> 29" in migration
assert "permission_digest_after is distinct from permission_digest_before" in migration
for removed in sorted(finance_areas - {"payments_management"}):
    assert f"'{removed}'" in migration
for forbidden in (
    "insert into public.employee_section_permissions",
    "update public.employee_section_permissions",
    "delete from public.employee_section_permissions",
    "delete from public.gs_orders",
    "delete from public.gs_payments",
    "truncate ",
):
    assert forbidden not in migration, f"Unexpected data/grant mutation: {forbidden}"

assert read("release/VERSION").strip() == "1.0.0.14"
print(
    "Payment Management consolidation contract passed: 29 visible sections, "
    "six retained permission paths, and catalog-only migration."
)
