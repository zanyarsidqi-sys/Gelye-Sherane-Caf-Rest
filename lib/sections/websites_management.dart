import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/website_settings_panel.dart';
import '../shared/staff_public_requests_panel.dart';
import '../shared/staff_fulfillment_panel.dart';

class WebsitesManagementScreen extends StatelessWidget {
  const WebsitesManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => SectionShell(
    title: 'Website Management',
    description: 'Update your public photos, contact details, and guest options',
    sectionId: 'websites_management',
    authorizedContent: DefaultTabController(length: 3, child: Column(children: const [
      TabBar(tabs: [Tab(text: 'Website editor'),Tab(text: 'Request review'),Tab(text: 'Fulfillment')]),
      Expanded(child: TabBarView(children: [
        WebsiteSettingsPanel(),
        SingleChildScrollView(child: StaffPublicRequestsPanel()),
        SingleChildScrollView(child: StaffFulfillmentPanel()),
      ])),
    ])),
  );
}
