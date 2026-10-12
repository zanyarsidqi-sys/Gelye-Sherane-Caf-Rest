import '../shared/professional_section_summary.dart';
import '../shared/kitchen_station_accounts_panel.dart';
import '../shared/kitchen_station_requests_panel.dart';
import '../shared/station_print_review_panel.dart';
import '../shared/product_station_mapping_panel.dart';
import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/live_kitchen_panel.dart';
import '../shared/station_assignment_panel.dart';
import '../shared/station_device_panel.dart';
import '../shared/station_management_panel.dart';
import '../shared/kitchen_service_tasks_panel.dart';
import '../shared/kitchen_delivery_tasks_panel.dart';
import '../shared/kitchen_correction_revisions_panel.dart';
import '../shared/kitchen_scheduled_motel_meals_panel.dart';
import '../shared/kitchen_motel_food_queue_panel.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});
  @override
  Widget build(BuildContext context) => const SectionShell(
    title: 'Kitchen',
    description: 'Accept, prepare and serve orders',
    sectionId: 'kitchen',
    authorizedContent: DefaultTabController(
      length: 13,
      child: Column(children: [
        ProfessionalSectionSummary(title: 'Kitchen workspace', subtitle: 'Live authorized kitchen workflows', icon: Icons.restaurant_menu, items: ['Orders', 'Stations', 'Service', 'Printing']),
        TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [Tab(text: 'Kitchen Orders'), Tab(text: 'Scheduled Motel Meals'), Tab(text: 'Motel Food Requests'), Tab(text: 'Stations'), Tab(text: 'Product Routing'), Tab(text: 'Station Staff'), Tab(text: 'Station Devices'), Tab(text: 'Service Tasks'), Tab(text: 'Station Requests'), Tab(text: 'Ready to Deliver'), Tab(text: 'Wrong Orders'), Tab(text: 'Print Review'), Tab(text: 'Station POS Accounts')]),
        Expanded(child: TabBarView(children: [
          LiveKitchenPanel(),
          KitchenScheduledMotelMealsPanel(),
          KitchenMotelFoodQueuePanel(),
          StationManagementPanel(),
          ProductStationMappingPanel(),
          StationAssignmentPanel(),
          StationDevicePanel(),
          KitchenServiceTasksPanel(),
          const KitchenStationRequestsPanel(),
          KitchenDeliveryTasksPanel(),
          KitchenCorrectionRevisionsPanel(),
          StationPrintReviewPanel(),
          KitchenStationAccountsPanel(),
        ])),
      ]),
    ),
  );
}
