from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
MIGRATION = (ROOT / "supabase/migrations/20261013_1501_customer_table_order_review.sql").read_text()
CUSTOMER = (ROOT / "lib/shared/customer_table_qr_menu_screen.dart").read_text()
TABLES = (ROOT / "lib/sections/tables.dart").read_text()
ROUTING = (ROOT / "lib/app/cafe_app.dart").read_text()
STAFF = (ROOT / "lib/shared/staff_table_order_requests_screen.dart").read_text()
ORDERS = (ROOT / "lib/sections/table_orders.dart").read_text()
WORKFLOW = (ROOT / ".github/workflows/validate-1.0.0.7-orders.yml").read_text()


class CustomerTableOrderReviewTests(unittest.TestCase):
    def test_public_submission_is_visit_bound_and_does_not_create_live_order(self):
        submit = MIGRATION.split(
            "create or replace function public.gs_public_submit_table_order_request", 1
        )[1].split("revoke all on function public.gs_public_submit_table_order_request", 1)[0]
        self.assertIn("p_table_qr_token", submit)
        self.assertIn("p_session_token", submit)
        self.assertIn("v.status = 'open'", submit)
        self.assertIn("q.table_id = s.table_id", submit)
        self.assertIn("p_idempotency_key", submit)
        self.assertIn("on conflict (visit_id, idempotency_key) do nothing", submit)
        self.assertNotIn("gs_create_cart_order", submit)
        self.assertIn("Too many requests for this visit", submit)

    def test_staff_acceptance_is_authorized_idempotent_and_visit_linked(self):
        accept = MIGRATION.split(
            "create or replace function public.gs_staff_accept_customer_table_order_request", 1
        )[1].split("revoke all on function public.gs_staff_accept_customer_table_order_request", 1)[0]
        self.assertIn("gs_can_access('table_orders', 'can_edit')", accept)
        self.assertIn("gs_can_access('table_orders', 'can_create')", accept)
        self.assertIn("if r.status = 'accepted' then return r.order_id", accept)
        self.assertIn("public.gs_create_cart_order(", accept)
        self.assertIn("set table_visit_id = r.visit_id", accept)
        self.assertIn("set preparation_notes", accept)
        self.assertIn("'accepted', auth.uid(), v_order_id", accept)

    def test_public_tables_are_not_directly_accessible_and_audit_is_immutable(self):
        self.assertIn(
            "revoke all on public.gs_customer_table_order_requests from public, anon, authenticated",
            MIGRATION,
        )
        self.assertIn(
            "revoke all on public.gs_customer_table_order_request_events from public, anon, authenticated",
            MIGRATION,
        )
        self.assertIn("gs_customer_table_order_event_immutable", MIGRATION)
        self.assertIn("gs_customer_table_order_request_status", MIGRATION)
        self.assertIn("gs_staff_reject_customer_table_order_request", MIGRATION)

    def test_customer_submission_uses_staff_visit_session_and_retry_reference(self):
        self.assertIn("Uri.base.queryParameters['visit']", ROUTING)
        self.assertIn("gs_public_submit_table_order_request", CUSTOMER)
        self.assertIn("gs_customer_table_order_request_status", CUSTOMER)
        self.assertIn("_retryKey", CUSTOMER)
        self.assertIn("Staff reviews each request before it becomes an order", CUSTOMER)
        self.assertIn("Prices are recalculated by the server", CUSTOMER)

    def test_staff_can_issue_visit_link_and_review_requests(self):
        self.assertIn("gs_staff_issue_customer_visit_session", TABLES)
        self.assertIn("'visit': visitToken", TABLES)
        self.assertIn("StaffTableOrderRequestsScreen()", ORDERS)
        self.assertIn("gs_staff_list_customer_table_order_requests", STAFF)
        self.assertIn("gs_staff_accept_customer_table_order_request", STAFF)
        self.assertIn("gs_staff_reject_customer_table_order_request", STAFF)

    def test_ci_is_staging_only_and_has_no_deploy_step(self):
        self.assertIn("staging/release-1.0.0.7-orders", WORKFLOW)
        self.assertIn("flutter analyze --no-fatal-infos", WORKFLOW)
        self.assertIn("flutter test", WORKFLOW)
        self.assertNotIn("deploy-pages", WORKFLOW)


if __name__ == "__main__":
    unittest.main()
