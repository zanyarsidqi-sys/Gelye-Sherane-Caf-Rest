import '../shared/app_language.dart';
import 'payments_management.dart';
import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/order_preview_workspace.dart';
import '../shared/motel_room_registry_screen.dart';
import '../shared/motel_scheduled_meals_screen.dart';
import '../shared/motel_food_requests_screen.dart';
import '../shared/motel_food_billing_ledger_screen.dart';

class MotelOrdersScreen extends StatelessWidget {
  const MotelOrdersScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Motel Orders',
    description: 'Deliver food to motel rooms',
    sectionId: 'motel_orders',
    authorizedContent: _MotelTabs(),
  );
}

class _MotelTabs extends StatelessWidget {
  const _MotelTabs();
  @override
  Widget build(BuildContext context) {
    String t(String value) => AppLanguage.label(AppLanguage.of(context), value);
    return DefaultTabController(
    length: 6,
    child: Column(children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'Motel Food Ledger is the charge source. Pending Payment is read-only settlement inspection; posted invoice totals are not verified unpaid balances. Prepaid and prior settlements must be checked before any collection.',
          style: TextStyle(fontSize: 12),
        ),
      ),
      TabBar(tabs: [Tab(text: t('Motel Orders')), Tab(text: t('Rooms')), Tab(text: t('Scheduled Meals')), const Tab(text: 'Food Requests'), const Tab(text: 'Food Ledger'), const Tab(text: 'Pending Payment')]),
      const Expanded(child: TabBarView(children: [
        OrderPreviewWorkspace(kind: 'motel'),
        MotelRoomRegistryScreen(),
        MotelScheduledMealsScreen(),
        MotelFoodRequestsScreen(),
        MotelFoodBillingLedgerScreen(),
        PaymentsManagementScreen(initialFocus: 'pending'),
      ])),
    ]),
  );
  }
}
