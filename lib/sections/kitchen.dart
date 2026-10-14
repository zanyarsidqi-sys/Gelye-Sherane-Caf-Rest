import 'package:flutter/material.dart';

import '../services/employee_permission_service.dart';
import '../shared/kitchen_correction_revisions_panel.dart';
import '../shared/kitchen_delivery_tasks_panel.dart';
import '../shared/kitchen_motel_food_queue_panel.dart';
import '../shared/kitchen_scheduled_motel_meals_panel.dart';
import '../shared/kitchen_service_tasks_panel.dart';
import '../shared/kitchen_station_accounts_panel.dart';
import '../shared/kitchen_station_requests_panel.dart';
import '../shared/live_kitchen_panel.dart';
import '../shared/product_station_mapping_panel.dart';
import '../shared/professional_section_summary.dart';
import '../shared/section_shell.dart';
import '../shared/station_assignment_panel.dart';
import '../shared/station_device_panel.dart';
import '../shared/station_management_panel.dart';
import '../shared/station_print_review_panel.dart';
import 'menu.dart';
import 'nargile_management.dart';
import 'products_inventory.dart';

const kitchenMergedSectionIds = <String>[
  'kitchen',
  'nargile_management',
  'menu',
  'products_inventory',
];

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key, this.initialSectionId = 'kitchen'});

  final String initialSectionId;

  @override
  Widget build(BuildContext context) => SectionShell(
        title: 'Kitchen',
        description: 'Orders, shisha, menu, products and stock in one workspace',
        sectionId: 'kitchen',
        additionalAccessSectionIds: const [
          'nargile_management',
          'menu',
          'products_inventory',
        ],
        authorizedContent: _KitchenWorkspace(
          initialSectionId: initialSectionId,
        ),
      );
}

class _KitchenWorkspace extends StatefulWidget {
  const _KitchenWorkspace({required this.initialSectionId});

  final String initialSectionId;

  @override
  State<_KitchenWorkspace> createState() => _KitchenWorkspaceState();
}

class _KitchenWorkspaceState extends State<_KitchenWorkspace> {
  late Future<Map<String, SectionPermission>> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = EmployeePermissionService().getSectionPermissions();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, SectionPermission>>(
        future: _permissions,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kitchen access could not be verified. Recheck employee access and try again.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final grants = snapshot.data!;
          final modules = <_KitchenModule>[
            if (grants['kitchen']?.canView == true)
              const _KitchenModule(
                id: 'kitchen',
                label: 'Kitchen Orders',
                icon: Icons.soup_kitchen_outlined,
                child: _KitchenOperations(),
              ),
            if (grants['nargile_management']?.canView == true)
              const _KitchenModule(
                id: 'nargile_management',
                label: 'Nargile (Shisha)',
                icon: Icons.smoking_rooms_outlined,
                child: NargileManagementScreen(compact: true),
              ),
            if (grants['menu']?.canView == true)
              const _KitchenModule(
                id: 'menu',
                label: 'Menu Management',
                icon: Icons.restaurant_menu_outlined,
                child: MenuScreen(compact: true),
              ),
            if (grants['products_inventory']?.canView == true)
              const _KitchenModule(
                id: 'products_inventory',
                label: 'Product & Inventory',
                icon: Icons.inventory_2_outlined,
                child: ProductsInventoryScreen(compact: true),
              ),
          ];

          if (modules.isEmpty) {
            return const Center(
              child: Text('No Kitchen, Menu, Nargile or Inventory access is enabled for this account.'),
            );
          }

          final requestedIndex =
              modules.indexWhere((module) => module.id == widget.initialSectionId);
          final initialIndex = requestedIndex < 0 ? 0 : requestedIndex;
          return DefaultTabController(
            length: modules.length,
            initialIndex: initialIndex,
            child: Column(
              children: [
                ProfessionalSectionSummary(
                  title: 'Kitchen workspace',
                  subtitle: 'Live service tools, grouped by your existing access',
                  icon: Icons.restaurant_menu,
                  items: modules.map((module) => module.label).toList(),
                ),
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      for (final module in modules)
                        Tab(
                          icon: Icon(module.icon, size: 18),
                          text: module.label,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [for (final module in modules) module.child],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _KitchenModule {
  const _KitchenModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.child,
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget child;
}

class _KitchenOperations extends StatelessWidget {
  const _KitchenOperations();

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Orders'),
                  Tab(text: 'Preparation'),
                  Tab(text: 'Printers & Staff'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _KitchenOrderWorkflows(),
                  _KitchenPreparationWorkflows(),
                  _KitchenDeviceWorkflows(),
                ],
              ),
            ),
          ],
        ),
      );
}

class _KitchenOrderWorkflows extends StatelessWidget {
  const _KitchenOrderWorkflows();

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 5,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Live Orders'),
                  Tab(text: 'Scheduled Meals'),
                  Tab(text: 'Motel Requests'),
                  Tab(text: 'Ready to Deliver'),
                  Tab(text: 'Order Corrections'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  LiveKitchenPanel(),
                  KitchenScheduledMotelMealsPanel(),
                  KitchenMotelFoodQueuePanel(),
                  KitchenDeliveryTasksPanel(),
                  KitchenCorrectionRevisionsPanel(),
                ],
              ),
            ),
          ],
        ),
      );
}

class _KitchenPreparationWorkflows extends StatelessWidget {
  const _KitchenPreparationWorkflows();

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Stations'),
                  Tab(text: 'Product Routing'),
                  Tab(text: 'Service Tasks'),
                  Tab(text: 'Requests'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  StationManagementPanel(),
                  ProductStationMappingPanel(),
                  KitchenServiceTasksPanel(),
                  KitchenStationRequestsPanel(),
                ],
              ),
            ),
          ],
        ),
      );
}

class _KitchenDeviceWorkflows extends StatelessWidget {
  const _KitchenDeviceWorkflows();

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Devices'),
                  Tab(text: 'Print Review'),
                  Tab(text: 'Station Accounts'),
                  Tab(text: 'Staff Assignments'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  StationDevicePanel(),
                  StationPrintReviewPanel(),
                  KitchenStationAccountsPanel(),
                  StationAssignmentPanel(),
                ],
              ),
            ),
          ],
        ),
      );
}
