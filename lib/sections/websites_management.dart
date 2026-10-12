import 'package:flutter/material.dart';
import '../shared/section_shell.dart';
import '../shared/website_settings_panel.dart';
import '../shared/staff_public_requests_panel.dart';
import '../shared/staff_fulfillment_panel.dart';

class WebsitesManagementScreen extends StatelessWidget {
  const WebsitesManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => SectionShell(
    title: 'Websites Management',
    description: 'Public website settings and incoming requests',
    sectionId: 'websites_management',
    authorizedContent: DefaultTabController(length: 3, child: Column(children: const [
      TabBar(tabs: [Tab(text: 'Website settings'),Tab(text: 'Request review'),Tab(text: 'Fulfillment')]),
      SizedBox(height: 650, child: TabBarView(children: [
        SingleChildScrollView(child: WebsiteSettingsPanel()),
        SingleChildScrollView(child: StaffPublicRequestsPanel()),
        SingleChildScrollView(child: StaffFulfillmentPanel()),
      ])),
    ])),
  );
}
