import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cafe_workspace_repository.dart';

const _navy = Color(0xFF09243A);
const _deepNavy = Color(0xFF061A2B);
const _gold = Color(0xFFD6AA57);
const _cream = Color(0xFFFAF8F3);
const _ink = Color(0xFF182B3A);
const _muted = Color(0xFF677582);

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey =
    String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
const _supabaseExpectedProjectRef =
    String.fromEnvironment('SUPABASE_EXPECTED_PROJECT_REF');

String _permissionSlug(String label) => label
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

const _featuredSectionCards = {
  1: [
    'Current Customers',
    'Active Tables',
    "Today's Customers",
    "Today's Tables",
    'Table Status',
    'Reservations',
    'Waiting List',
    'Table Cleaning',
    'Table Requests',
    'Table Performance',
  ],
  3: [
    'Menu Management',
    'Inventory & Stock',
    'Nargile Management',
    'Preparation Time',
    'Kitchen Devices',
  ],
  4: [
    'Kitchen Orders',
    'Table Orders',
    'Online Orders',
    'Motel Orders',
    'Takeaway & Delivery',
    'Customer Requests',
  ],
  5: ['Reports & Analytics'],
  6: ['Permissions & Roles'],
  9: [
    'Settings & Configuration',
    'Backup & Restore',
    'Offline & Sync',
    'System Updates',
    'Devices & Printers',
  ],
  10: [
    'System Health',
    'Security Center',
    'Audit & Activity History',
  ],
};

const _sectionCardDescriptions = {
  'Current Customers': 'Live seated guests',
  'Active Tables': 'Occupied tables',
  "Today's Customers": 'Daily guest total',
  "Today's Tables": 'Visits opened today',
  'Table Status': 'All table states',
  'Reservations': 'Bookings & arrivals',
  'Waiting List': 'Waiting parties',
  'Table Cleaning': 'Cleaning approvals',
  'Table Requests': 'Service requests',
  'Table Performance': 'Turnover & timing',
  'Kitchen Orders': 'All kitchen orders and status',
  'Table Orders': 'Orders for occupied tables',
  'Online Orders': 'Orders from website and app',
  'Motel Orders': 'Orders from motel guests',
  'Takeaway & Delivery': 'Pickup and delivery orders',
  'Menu Management': 'Products, prices and availability',
  'Inventory & Stock': 'Stock quantities and alerts',
  'Nargile Management': 'Shisha orders and preparation',
  'Preparation Time': 'Kitchen speed and delayed orders',
  'Kitchen Devices': 'Printers, displays and device status',
  'Reports & Analytics': 'Sales, orders and performance reports',
  'System Health': 'Service status and system alerts',
  'Security Center': 'MFA and security monitoring',
  'Permissions & Roles': 'Employee roles and access control',
  'Audit & Activity History': 'Track staff system activity',
  'Backup & Restore': 'Data backup and recovery',
  'Offline & Sync': 'Pending synchronization and errors',
  'System Updates': 'App version and release management',
  'Settings & Configuration': 'Restaurant settings and preferences',
  'Devices & Printers': 'Manage connected devices',
};

String _staffFunctionFailure(FunctionException exception) {
  final details = exception.details;
  final serverMessage = details is Map ? details['error'] : null;
  if (serverMessage is String && serverMessage.isNotEmpty) {
    return serverMessage;
  }
  if (exception.status == 0) {
    return 'No response was received from the staff management service. Check the '
        'internet connection and confirm that this Edge Function is deployed '
        'to the selected Supabase project.';
  }
  if (exception.status == 404) {
    return 'The staff management Edge Function is not deployed to this '
        'Supabase project.';
  }
  return 'The staff management request failed (HTTP ${exception.status}).';
}

bool get _hasSupabaseConfiguration =>
    _supabaseUrl.isNotEmpty ||
    _supabasePublishableKey.isNotEmpty ||
    _supabaseExpectedProjectRef.isNotEmpty;

bool get _hasValidSupabaseConfiguration {
  final uri = Uri.tryParse(_supabaseUrl);
  return uri != null &&
      RegExp(r'^[a-z0-9]{20}$').hasMatch(_supabaseExpectedProjectRef) &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.port == 443 &&
      uri.host == '$_supabaseExpectedProjectRef.supabase.co' &&
      (uri.path.isEmpty || uri.path == '/') &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty &&
      _supabasePublishableKey.isNotEmpty;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_hasValidSupabaseConfiguration) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
  }
  runApp(
    CafeApp(
      supabaseConfigured: _hasValidSupabaseConfiguration,
      supabaseConfigurationProvided: _hasSupabaseConfiguration,
    ),
  );
}

class CafeApp extends StatelessWidget {
  const CafeApp({
    this.supabaseConfigured = false,
    this.supabaseConfigurationProvided = false,
    super.key,
  });

  final bool supabaseConfigured;
  final bool supabaseConfigurationProvided;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gelye Sherane Café & Restaurant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _gold,
          surface: Colors.white,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
      ),
      home: CafeLandingPage(
        supabaseConfigured: supabaseConfigured,
        supabaseConfigurationProvided: supabaseConfigurationProvided,
      ),
    );
  }
}

class CafeLandingPage extends StatefulWidget {
  const CafeLandingPage({
    this.supabaseConfigured = false,
    this.supabaseConfigurationProvided = false,
    super.key,
  });

  final bool supabaseConfigured;
  final bool supabaseConfigurationProvided;

  @override
  State<CafeLandingPage> createState() => _CafeLandingPageState();
}

class _CafeLandingPageState extends State<CafeLandingPage> {
  final _menuKey = GlobalKey();
  final _visitKey = GlobalKey();

  Future<void> _scrollTo(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: 0.04,
    );
  }

  void _openReservation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ReservationDialog(
        onSubmitted: (name) {
          Navigator.of(dialogContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Thanks, $name. This preview does not send booking requests yet.',
              ),
            ),
          );
        },
      ),
    );
  }

  void _openStaffSignIn() {
    showDialog<void>(
      context: context,
      builder: (context) => StaffSignInDialog(
        supabaseConfigured: widget.supabaseConfigured,
        supabaseConfigurationProvided: widget.supabaseConfigurationProvided,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              CafeHeader(
                onMenu: () => _scrollTo(_menuKey),
                onAbout: () => _scrollTo(_visitKey),
                onBook: _openReservation,
                onStaff: _openStaffSignIn,
              ),
              _PageSection(
                child: _HeroSection(
                  onBook: _openReservation,
                  onMenu: () => _scrollTo(_menuKey),
                ),
              ),
              const _FeatureStrip(),
              _PageSection(key: _menuKey, child: const _MenuSection()),
              KeyedSubtree(
                key: _visitKey,
                child: _VisitSection(onBook: _openReservation),
              ),
              const _CafeFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class CafeHeader extends StatelessWidget {
  const CafeHeader({
    required this.onMenu,
    required this.onAbout,
    required this.onBook,
    required this.onStaff,
    super.key,
  });

  final VoidCallback onMenu;
  final VoidCallback onAbout;
  final VoidCallback onBook;
  final VoidCallback onStaff;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        return Container(
          color: _deepNavy,
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 36 : 20,
            vertical: 15,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Row(
                children: [
                  const _BrandMark(),
                  const Spacer(),
                  if (isWide) ...[
                    _HeaderLink(label: 'Home', onPressed: () {}),
                    _HeaderLink(label: 'Menu', onPressed: onMenu),
                    _HeaderLink(label: 'Our café', onPressed: onAbout),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: onStaff,
                      icon: const Icon(Icons.lock_outline, size: 17),
                      label: const Text('Staff sign in'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: onBook,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _deepNavy,
                      ),
                      child: const Text('Book a table'),
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: 'Open menu',
                      onPressed: () => _showMobileMenu(
                        context,
                        onMenu,
                        onAbout,
                        onBook,
                        onStaff,
                      ),
                      icon: const Icon(Icons.menu, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMobileMenu(
    BuildContext context,
    VoidCallback onMenu,
    VoidCallback onAbout,
    VoidCallback onBook,
    VoidCallback onStaff,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MobileMenuItem(
                label: 'Home',
                onPressed: () => Navigator.pop(context),
              ),
              _MobileMenuItem(
                label: 'Menu',
                onPressed: () {
                  Navigator.pop(context);
                  onMenu();
                },
              ),
              _MobileMenuItem(
                label: 'Our café',
                onPressed: () {
                  Navigator.pop(context);
                  onAbout();
                },
              ),
              _MobileMenuItem(
                label: 'Staff sign in',
                onPressed: () {
                  Navigator.pop(context);
                  onStaff();
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onBook();
                  },
                  child: const Text('Book a table'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileMenuItem extends StatelessWidget {
  const _MobileMenuItem({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: onPressed,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Color(0xFFF0CB83), _gold]),
          ),
          alignment: Alignment.center,
          child: const Text(
            'G',
            style: TextStyle(
              color: _deepNavy,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              fontFamily: 'serif',
            ),
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gelye Sherane',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'CAFÉ & RESTAURANT',
              style: TextStyle(
                color: Color(0xFFD5B77C),
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.88),
      ),
      child: Text(label),
    );
  }
}

class _PageSection extends StatelessWidget {
  const _PageSection({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
          child: child,
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.onBook, required this.onMenu});

  final VoidCallback onBook;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        return Container(
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.16),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                right: -70,
                top: -145,
                child: Container(
                  width: 390,
                  height: 390,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isWide ? 52 : 27),
                child: Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: isWide ? 6 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Eyebrow('WELCOME TO'),
                          const SizedBox(height: 17),
                          Text(
                            'Gelye Sherane\nCafé & Restaurant',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isWide ? 49 : 38,
                              height: 1.08,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Enjoy delicious food, a relaxing atmosphere, and '
                            'the natural beauty of Gelye Sherane with family '
                            'and friends.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 16,
                              height: 1.65,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: onBook,
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: const Text('Book a table'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _gold,
                                  foregroundColor: _deepNavy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: onMenu,
                                icon: const Icon(Icons.restaurant_menu),
                                label: const Text('Explore menu'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isWide) const SizedBox(width: 40),
                    Expanded(
                      flex: isWide ? 5 : 0,
                      child: Padding(
                        padding: EdgeInsets.only(top: isWide ? 0 : 30),
                        child: const _CafeIllustration(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CafeIllustration extends StatelessWidget {
  const _CafeIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24465D), Color(0xFF102E43)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 20,
            right: 28,
            child: _SmallPill(
              icon: Icons.spa_outlined,
              label: 'Fresh ingredients',
            ),
          ),
          Positioned(
            bottom: 22,
            left: 22,
            child: _SmallPill(
              icon: Icons.favorite_border,
              label: 'Made with care',
            ),
          ),
          Container(
            width: 205,
            height: 205,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.12),
              border: Border.all(color: _gold.withValues(alpha: 0.28)),
            ),
          ),
          const Icon(Icons.local_cafe, size: 142, color: Color(0xFFE6BE74)),
          Positioned(
            bottom: 71,
            right: 77,
            child: Container(
              width: 41,
              height: 41,
              decoration: const BoxDecoration(
                color: Color(0xFFFAF8F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: _gold, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _gold, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _gold,
        letterSpacing: 2.1,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  static const _features = [
    (Icons.restaurant, 'Delicious food', 'Local & international'),
    (Icons.eco_outlined, 'Fresh ingredients', 'Quality in every bite'),
    (Icons.groups_outlined, 'Family friendly', 'A place for everyone'),
    (Icons.event_available_outlined, 'Table reservations', 'Plan your visit'),
    (Icons.celebration_outlined, 'Events & parties', 'Celebrate together'),
    (Icons.local_parking_outlined, 'Free parking', 'Convenient arrival'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 580
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _features.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 91,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final feature = _features[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFECE8E0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(feature.$1, color: _navy),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                feature.$3,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection();

  static const _items = [
    (
      Icons.coffee,
      'Coffee & tea',
      'A comforting cup, prepared fresh for your visit.',
      Color(0xFF8C5D39),
    ),
    (
      Icons.breakfast_dining,
      'Breakfast',
      'A relaxed start to the day with something delicious.',
      Color(0xFFB77C35),
    ),
    (
      Icons.dinner_dining,
      'Lunch & dinner',
      'Local and international favorites for every appetite.',
      Color(0xFF567C5A),
    ),
    (
      Icons.bakery_dining,
      'Fresh pastries',
      'A little something sweet to enjoy with your coffee.',
      Color(0xFF9A6680),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          eyebrow: 'SOMETHING FOR EVERY MOMENT',
          title: 'A taste to look forward to',
          subtitle: 'Settle in for coffee, share a meal, or treat yourself to something fresh.',
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 206,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFECE8E0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 49,
                        height: 49,
                        decoration: BoxDecoration(
                          color: item.$4.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(item.$1, color: item.$4, size: 26),
                      ),
                      const Spacer(),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 14),
        const Text(
          'Menu items and availability may vary. Please ask our team for today’s menu.',
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _VisitSection extends StatelessWidget {
  const _VisitSection({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _deepNavy,
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 43),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: isWide
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isWide ? 7 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Eyebrow('COME BY AND SAY HELLO'),
                          const SizedBox(height: 12),
                          const Text(
                            'Make time for a good meal.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            'Ask our team about current opening hours, directions, '
                            'and availability.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isWide) const SizedBox(width: 24),
                    if (!isWide) const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: onBook,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Plan a visit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _deepNavy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 21,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CafeFooter extends StatelessWidget {
  const _CafeFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _deepNavy,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                const Expanded(child: _BrandMark()),
                Text(
                  '© ${DateTime.now().year} Gelye Sherane Café & Restaurant',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(eyebrow),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 31,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Text(
            subtitle,
            style: const TextStyle(color: _muted, height: 1.55),
          ),
        ),
      ],
    );
  }
}

class ReservationDialog extends StatefulWidget {
  const ReservationDialog({required this.onSubmitted, super.key});

  final ValueChanged<String> onSubmitted;

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _guests = 2;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmitted(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Plan your visit'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Share your details and our team can help with your plans.',
                    style: TextStyle(color: _muted, height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) => value == null || value.trim().length < 6
                      ? 'Enter a valid phone number'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _chooseDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${_date.day}/${_date.month}/${_date.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<int>(
                      value: _guests,
                      onChanged: (value) {
                        if (value != null) setState(() => _guests = value);
                      },
                      items: List.generate(
                        8,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1} guests'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Preview only: requests are not sent or stored.',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send request')),
      ],
    );
  }
}

class StaffDashboardPage extends StatefulWidget {
  const StaffDashboardPage({
    required this.email,
    required this.role,
    this.grantedPermissions = const {},
    this.permissionsLoadError,
    super.key,
  });

  final String email;
  final String role;
  final Set<String> grantedPermissions;
  final String? permissionsLoadError;

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  static const _sections = [
    (
      key: 'dashboard',
      icon: Icons.dashboard_outlined,
      title: 'Dashboard',
      description: 'Live overview of your restaurant operations.',
    ),
    (
      key: 'tables_orders',
      icon: Icons.table_restaurant_outlined,
      title: 'Tables & Orders',
      description: 'Table occupancy, orders, reservations and QR actions.',
    ),
    (
      key: 'payment_management',
      icon: Icons.payments_outlined,
      title: 'Payment Management',
      description: 'Payments, pending balances, refunds and reconciliation.',
    ),
    (
      key: 'kitchen_management',
      icon: Icons.soup_kitchen_outlined,
      title: 'Kitchen Management',
      description: 'Kitchen queue, preparation status and product availability.',
    ),
    (
      key: 'customer_management',
      icon: Icons.people_outline,
      title: 'Customer Management',
      description: 'Customer orders, requests, feedback and history.',
    ),
    (
      key: 'statistics_management',
      icon: Icons.query_stats_outlined,
      title: 'Statistics Management',
      description: 'Revenue, product performance and service metrics.',
    ),
    (
      key: 'employee_management',
      icon: Icons.badge_outlined,
      title: 'Employee Management',
      description: 'Staff attendance, tasks, permissions and activity.',
    ),
    (
      key: 'maintenance_management',
      icon: Icons.build_outlined,
      title: 'Maintenance Management',
      description: 'Equipment, maintenance alerts and repair history.',
    ),
    (
      key: 'notifications_management',
      icon: Icons.notifications_none_outlined,
      title: 'Notifications Management',
      description: 'Operational alerts and staff notifications.',
    ),
    (
      key: 'settings_management',
      icon: Icons.settings_outlined,
      title: 'Settings Management',
      description: 'Cafe configuration, preferences and system settings.',
    ),
    (
      key: 'operations_management',
      icon: Icons.tune_outlined,
      title: 'Operations Management',
      description: 'System health, audit history and operational controls.',
    ),
  ];

  static const _subcards = [
    [
      'Today Revenue',
      'Standing Cash',
      'Pending Payment',
      'Invoices',
      'Discounts',
      'Credit Accounts',
      'Tables Occupied',
      'Table Map',
      'Cleaning Needed',
      'Guests Today',
      'Today Orders',
      'Kitchen Orders',
      'Menu',
      'Low Stock',
      'Nargile Orders',
      'Table Occupancy',
      'Kitchen Queue',
      'Motel Orders',
      'Online Orders',
      'Tourism Customers',
      'Reservations',
      'Customer Requests',
      'Takeaway & Delivery',
      'Attendance',
      'Customers',
      'Employees',
      'Tasks',
      'Events',
      'Cash Reconciliation',
      'Product Performance',
      'Service Speed',
      'Feedback',
      'Maintenance',
      'Reports',
      'Security',
      'Backup',
      'Offline Mode',
      'System Health',
      'Audit & Activity',
      'Personalization',
    ],
    [
      'Current Customers',
      'Active Tables',
      "Today's Customers",
      "Today's Tables",
      'Table Status',
      'Reservations',
      'Waiting List',
      'Table Cleaning',
      'Table Requests',
      'Table Performance',
      'Table Overview',
      'Visual Table Map',
      'Add/Edit Tables & Chairs',
      'QR Generate/Print/Revoke',
      'Table Orders',
      'Customer QR Screen',
      'Pricing Modes',
      'Join/Transfer',
      'Split Bills',
      'Pay for Others',
      'Cleaning',
      'Table History',
      'Extra Chairs',
    ],
    [
      'Today Revenue',
      'Revenue',
      'Standing Cash',
      'Pending Payments',
      'Collected Cash',
      'Available Cash',
      'Cash Over / Short',
      'Expenses',
      'Invoices & Payments',
      'Table Income',
      'Refunds & Voids',
      'Confirm Credit',
      'Costs & Expenses',
      'Invoices',
      'Payment Collection',
      'Cash/Card/Online',
      'Pending Payment',
      'Customer Credit',
      'Discounts',
      'Refunds',
      'Cash Reconciliation',
      'Approvals',
      'Audit',
    ],
    [
      'Menu Management',
      'Inventory & Stock',
      'Nargile Management',
      'Preparation Time',
      'Kitchen Devices',
      'Kitchen Queue',
      'Stations',
      'Menu Categories',
      'Add/Edit Products',
      'Modifiers',
      'Price Rules',
      'Available/Out of Stock',
      'Inventory',
      'Purchasing',
      'Suppliers',
      'Nargile',
      'Recipes',
      'Printers',
      'Revisions',
    ],
    [
      'Kitchen Orders',
      'Table Orders',
      'Online Orders',
      'Motel Orders',
      'Takeaway & Delivery',
      'Customer Requests',
      'Customer Directory',
      'Takeaway',
      'Delivery',
      'QR Customer Ordering',
      'Credit Profile',
      'Requests',
      'Feedback',
      'Meal Packages',
      'Delivery Schedule',
      'History',
      'Events',
    ],
    [
      'Reports & Analytics',
      'Revenue Reports',
      'Cost & Profit',
      'Sales Analytics',
      'Product Performance',
      'Occupancy',
      'Tourism',
      'Employee KPIs',
      'Kitchen Speed',
      'Feedback',
      'Outstanding Balances',
      'Exports',
      'Comparisons',
    ],
    [
      'Permissions & Roles',
      'Staff Directory',
      'Invite/Create Staff',
      'Roles',
      'Permissions',
      'Attendance',
      'Shifts',
      'Tasks',
      'Performance',
      'MFA',
      'Account Status',
      'Activity',
      'Payroll Inputs',
    ],
    [
      'Faults',
      'Equipment',
      'Cleaning',
      'Preventive Schedule',
      'Assignments',
      'Priorities',
      'Repair Cost',
      'Evidence',
      'Completion',
      'History',
    ],
    [
      'Action Center',
      'Orders',
      'Kitchen',
      'Payments',
      'Requests',
      'Tasks',
      'Reservations',
      'Security',
      'Printer/Offline',
      'History',
      'Acknowledgments',
    ],
    [
      'Settings & Configuration',
      'Backup & Restore',
      'Offline & Sync',
      'System Updates',
      'Devices & Printers',
      'General',
      'Device Layout',
      'Appearance/Dark Mode',
      'Dictionary & Languages',
      'Invoice Designer',
      'Website',
      'Offline Sync',
      'Security',
      'Publishing',
      'Health',
      'Test/Real Mode',
    ],
    [
      'System Health',
      'Security Center',
      'Audit & Activity History',
      'Opening Checklist',
      'Shift Handover',
      'Closing Checklist',
      'Department Status',
      'Work Assignments',
      'Approvals',
      'Incidents',
      'Outstanding Tasks',
      'Operations History',
      'Events',
    ],
  ];

  bool _hasSectionAccess(int sectionIndex) {
    if (widget.role == 'admin' || sectionIndex == 0) return true;
    return _visibleSubcards(sectionIndex).isNotEmpty;
  }

  List<int> get _visibleSectionIndices => [
    for (var index = 0; index < _sections.length; index++)
      if (_hasSectionAccess(index)) index,
  ];

  List<String> _visibleSubcards(int sectionIndex) {
    final sectionKey = _sections[sectionIndex].key;
    if (widget.role == 'admin' ||
        widget.grantedPermissions.contains('$sectionKey:*')) {
      return _subcards[sectionIndex];
    }
    return _subcards[sectionIndex]
        .where(
          (subcard) => widget.grantedPermissions.contains(
            '$sectionKey:${_permissionSlug(subcard)}',
          ),
        )
        .toList(growable: false);
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex = 0;
  String? _selectedSubcard;
  bool _isSigningOut = false;
  String? _signOutError;
  CafeWorkspaceRepository? _workspaceRepository;
  RealtimeChannel? _workspaceChannel;
  List<CafeWorkspaceRecord> _workspaceRecords = const [];
  bool _isLoadingRecords = true;
  bool _isFetchingRecords = false;
  String? _workspaceError;
  List<Map<String, dynamic>> _staffDepartments = const [];
  List<Map<String, dynamic>> _staffPermissionProfiles = const [];
  List<Map<String, dynamic>> _staffMembers = const [];
  bool _isLoadingEmployeeData = false;
  String? _employeeManagementError;
  DateTime _selectedReportDate = DateTime.now();
  String _selectedDateRange = 'Today';
  String _financeStatusFilter = 'All';
  String _financeSearch = '';

  @override
  void initState() {
    super.initState();
    unawaited(_connectWorkspace());
    if (widget.role == 'admin') {
      unawaited(_loadEmployeeManagement());
    }
  }

  @override
  void dispose() {
    final channel = _workspaceChannel;
    final repository = _workspaceRepository;
    if (channel != null && repository != null) {
      unawaited(repository.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _connectWorkspace() async {
    if (!_hasValidSupabaseConfiguration) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecords = false;
        _workspaceError =
            'Supabase is not configured with a valid project URL and key.';
      });
      return;
    }
    try {
      final repository = CafeWorkspaceRepository(
        Supabase.instance.client,
      );
      _workspaceRepository = repository;
      _workspaceChannel = repository.subscribe(() {
        unawaited(_loadWorkspaceRecords());
      });
      await _loadWorkspaceRecords();
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecords = false;
        _workspaceError = 'Supabase is not configured for this app: $exception';
      });
    }
  }

  Future<void> _loadWorkspaceRecords() async {
    final repository = _workspaceRepository;
    if (repository == null || _isFetchingRecords) return;
    _isFetchingRecords = true;
    if (mounted) {
      setState(() {
        _isLoadingRecords = true;
        _workspaceError = null;
      });
    }
    try {
      final records = await repository.fetchRecords();
      if (!mounted) return;
      setState(() {
        _workspaceRecords = records;
        _workspaceError = null;
      });
    } on PostgrestException catch (exception) {
      if (!mounted) return;
      setState(() {
        _workspaceError =
            'Live records could not be loaded (${exception.code ?? 'unknown'}): '
            '${exception.message}';
      });
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _workspaceError = 'Live records could not be loaded: $exception';
      });
    } finally {
      _isFetchingRecords = false;
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  List<CafeWorkspaceRecord> _recordsFor(
    String sectionKey,
    String subcardKey,
  ) =>
      _workspaceRecords
          .where(
            (record) =>
                record.sectionKey == sectionKey &&
                record.subcardKey == subcardKey,
          )
          .toList(growable: false);

  List<CafeWorkspaceRecord> _recordsInSelectedRange(
    Iterable<CafeWorkspaceRecord> records,
  ) {
    final selectedDay = DateTime(
      _selectedReportDate.year,
      _selectedReportDate.month,
      _selectedReportDate.day,
    );
    final start = switch (_selectedDateRange) {
      'Yesterday' => selectedDay.subtract(const Duration(days: 1)),
      'This Week' => selectedDay.subtract(
        Duration(days: selectedDay.weekday - 1),
      ),
      'This Month' => DateTime(selectedDay.year, selectedDay.month),
      'This Year' => DateTime(selectedDay.year),
      _ => selectedDay,
    };
    final end = switch (_selectedDateRange) {
      'This Week' => start.add(const Duration(days: 7)),
      'This Month' => DateTime(start.year, start.month + 1),
      'This Year' => DateTime(start.year + 1),
      _ => start.add(const Duration(days: 1)),
    };
    return records
        .where(
          (record) =>
              !record.createdAt.isBefore(start) && record.createdAt.isBefore(end),
        )
        .toList(growable: false);
  }

  String _connectionLabel(String sectionKey, String subcardKey) {
    if (_workspaceError != null) return 'Unavailable';
    if (_isLoadingRecords) return 'Connecting...';
    final count = _recordsFor(sectionKey, subcardKey).length;
    return count == 0
        ? 'Connected · no records'
        : 'Connected · $count record${count == 1 ? '' : 's'}';
  }

  Future<Map<String, dynamic>> _callStaffFunction(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (!_hasValidSupabaseConfiguration) {
      throw const FormatException(
        'Supabase is not configured for employee management.',
      );
    }
    final response = await Supabase.instance.client.functions.invoke(
      'create-staff-user',
      body: {'action': action, ...payload},
    );
    if (response.data is! Map) {
      throw const FormatException(
        'The staff management service returned an invalid response.',
      );
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> _loadEmployeeManagement() async {
    if (!mounted || _isLoadingEmployeeData) return;
    if (!_hasValidSupabaseConfiguration) {
      setState(() {
        _employeeManagementError =
            'Supabase is not configured for employee management in this deployment.';
      });
      return;
    }
    setState(() {
      _isLoadingEmployeeData = true;
      _employeeManagementError = null;
    });
    try {
      final result = await _callStaffFunction('list-management');
      if (!mounted) return;
      setState(() {
        _staffDepartments = _mapList(result['departments']);
        _staffPermissionProfiles = _mapList(result['permission_profiles']);
        _staffMembers = _mapList(result['staff']);
      });
    } on FunctionException catch (exception) {
      if (!mounted) return;
      setState(() => _employeeManagementError = _staffFunctionFailure(exception));
    } on Exception catch (exception) {
      if (!mounted) return;
      setState(() {
        _employeeManagementError =
            'Could not load employee management data: $exception';
      });
    } finally {
      if (mounted) setState(() => _isLoadingEmployeeData = false);
    }
  }

  Future<void> _createWorkspaceRecord(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) async {
    final repository = _workspaceRepository;
    if (repository == null) {
      setState(() {
        _workspaceError = 'The live Supabase service is not available.';
      });
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final detailsController = TextEditingController();
    final amountController = TextEditingController();
    var error = '';
    var submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add $subcard record'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a title'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (optional, IQD)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return double.tryParse(value.trim()) == null
                          ? 'Enter a valid amount'
                          : null;
                    },
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _AuthErrorMessage(error),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        submitting = true;
                        error = '';
                      });
                      try {
                        await repository.createRecord(
                          sectionKey: section.key,
                          subcardKey: _permissionSlug(subcard),
                          title: titleController.text.trim(),
                          details: detailsController.text.trim(),
                          amount: amountController.text.trim().isEmpty
                              ? null
                              : double.parse(amountController.text.trim()),
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on Exception catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            error = _workspaceWriteFailure(exception);
                            submitting = false;
                          });
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save record'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    detailsController.dispose();
    amountController.dispose();
    if (result == true) await _loadWorkspaceRecords();
  }

  String _workspaceWriteFailure(Exception exception) {
    if (exception is PostgrestException && exception.code == '42501') {
      return 'Supabase blocked this save with row-level security (42501); '
          'the record was not saved. Server reported: ${exception.message}. '
          'Verify this account has completed authenticator verification '
          '(AAL2), its staff profile has the correct role, any required '
          'section/card permission is assigned, and the reported table/schema '
          'matches this deployed app. If these checks pass, the production '
          'RLS policy needs a targeted correction. Do not disable RLS.';
    }
    if (exception is PostgrestException) {
      return 'Record was not saved (${exception.code ?? 'unknown'}): '
          '${exception.message}';
    }
    return 'Record was not saved. Check the connection and account access, '
        'then retry. $exception';
  }

  Future<void> _updateRecordStatus(
    CafeWorkspaceRecord record,
    String status,
  ) async {
    final repository = _workspaceRepository;
    if (repository == null) return;
    try {
      await repository.updateStatus(recordId: record.id, status: status);
      await _loadWorkspaceRecords();
    } on Exception catch (exception) {
      if (mounted) {
        setState(() {
          _workspaceError = 'Could not update this record: $exception';
        });
      }
    }
  }

  Future<void> _deleteWorkspaceRecord(CafeWorkspaceRecord record) async {
    final repository = _workspaceRepository;
    if (repository == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Delete "${record.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteRecord(record.id);
      await _loadWorkspaceRecords();
    } on Exception catch (exception) {
      if (mounted) {
        setState(() {
          _workspaceError = 'Could not delete this record: $exception';
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _signOutError = null;
    });
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } on AuthException {
      if (mounted) {
        setState(() {
          _signOutError = 'Sign-out failed. Please try again.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _signOutError =
              'Could not reach the sign-in service. Check your connection.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _openMoreSections() async {
    const primarySections = {0, 1, 2, 3};
    final moreSections = _visibleSectionIndices
        .where((index) => !primarySections.contains(index))
        .toList(growable: false);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'More management sections',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            if (moreSections.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text('No additional management sections are assigned.'),
              ),
            for (final index in moreSections)
              ListTile(
                leading: Icon(_sections[index].icon, color: _navy),
                title: Text(_sections[index].title),
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                    _selectedSubcard = null;
                  });
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDepartment({Map<String, dynamic>? department}) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(
      text: department?['name'] as String? ?? '',
    );
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(department == null ? 'Add department' : 'Edit department'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Department name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                        ? 'Enter a department name'
                        : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    _AuthErrorMessage(error!),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await _callStaffFunction('save-department', {
                          if (department != null) 'id': department['id'],
                          'name': controller.text.trim(),
                        });
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on FunctionException catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(
                            () => error = _staffFunctionFailure(exception),
                          );
                        }
                      } on Exception catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(
                            () => error = 'Could not save department: $exception',
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save department'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true) await _loadEmployeeManagement();
  }

  Future<void> _savePermissionProfile({
    Map<String, dynamic>? permissionProfile,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: permissionProfile?['name'] as String? ?? '',
    );
    final selectedPermissions = <String, Set<String>>{};
    final grants = permissionProfile?['permissions'];
    if (grants is List) {
      for (final grant in grants.whereType<Map>()) {
        final sectionKey = grant['section_key'];
        final subcardKey = grant['subcard_key'];
        if (sectionKey is String && subcardKey is String) {
          selectedPermissions
              .putIfAbsent(sectionKey, () => <String>{})
              .add(subcardKey);
        }
      }
    }
    String? selectedDepartmentId =
        permissionProfile?['department_id'] as String? ??
        (_staffDepartments.isEmpty
            ? null
            : _staffDepartments.first['id'] as String?);
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            if (selectedDepartmentId == null) {
              setDialogState(() => error = 'Create a department first.');
              return;
            }
            final permissions = [
              for (final entry in selectedPermissions.entries)
                for (final subcardKey in entry.value)
                  {'section_key': entry.key, 'subcard_key': subcardKey},
            ];
            if (permissions.isEmpty) {
              setDialogState(
                () => error = 'Select at least one section or card.',
              );
              return;
            }
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              await _callStaffFunction('save-permission-profile', {
                if (permissionProfile != null) 'id': permissionProfile['id'],
                'department_id': selectedDepartmentId,
                'name': nameController.text.trim(),
                'permissions': permissions,
              });
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } on FunctionException catch (exception) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = _staffFunctionFailure(exception),
                );
              }
            } on Exception catch (exception) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = 'Could not save permission profile: $exception',
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          final dialogHeight = MediaQuery.sizeOf(context).height;
          final contentHeight = (dialogHeight * 0.78).clamp(320.0, 680.0);
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 560,
              height: contentHeight,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            permissionProfile == null
                                ? 'Create permission profile'
                                : 'Edit permission profile',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Save a reusable set of section and card access.',
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Form(
                      key: formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextFormField(
                            controller: nameController,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'Permission profile name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter a profile name'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedDepartmentId,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final department in _staffDepartments)
                                DropdownMenuItem(
                                  value: department['id'] as String,
                                  child: Text(department['name'] as String),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) => setDialogState(
                                    () => selectedDepartmentId = value,
                                  ),
                            validator: (value) => value == null
                                ? 'Choose a department'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          for (var index = 0;
                              index < _StaffDashboardPageState._sections.length;
                              index++)
                            _buildStaffPermissionSection(
                              index,
                              selectedPermissions,
                              setDialogState,
                              saving,
                              titlePrefix: index == 0
                                  ? 'Dashboard cards'
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _AuthErrorMessage(error!),
                    ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving
                              ? null
                              : () => Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: saving ? null : submit,
                          child: Text(
                            saving ? 'Saving…' : 'Save permission profile',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    nameController.dispose();
    if (saved == true) await _loadEmployeeManagement();
  }

  Future<void> _addStaffUser() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    String? departmentId;
    String? permissionProfileId;
    var saving = false;
    String? error;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableProfiles = _staffPermissionProfiles
              .where((profile) => profile['department_id'] == departmentId)
              .toList(growable: false);
          if (!availableProfiles.any(
            (profile) => profile['id'] == permissionProfileId,
          )) {
            permissionProfileId = null;
          }
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() {
              saving = true;
              error = null;
            });
            try {
              final result = await _callStaffFunction('create-staff-user', {
                'email': emailController.text.trim(),
                'password': passwordController.text,
                'department_id': departmentId,
                'permission_profile_id': permissionProfileId,
              });
              if (result['permissions_saved'] != true) {
                throw const FormatException(
                  'The service did not confirm saving staff permissions.',
                );
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } on FunctionException catch (exception) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = _staffFunctionFailure(exception),
                );
              }
            } on AuthException {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = 'Your sign-in has expired. Sign in again.',
                );
              }
            } on Exception catch (exception) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => error = 'Could not create staff account: $exception',
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            title: const Text('Add staff account'),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Staff email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return email.contains('@') && email.contains('.')
                              ? null
                              : 'Enter a valid email address';
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Initial password (12+ characters)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.length < 12
                            ? 'Use at least 12 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: departmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final department in _staffDepartments)
                            DropdownMenuItem(
                              value: department['id'] as String,
                              child: Text(department['name'] as String),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(() {
                                departmentId = value;
                                permissionProfileId = null;
                              }),
                        validator: (value) =>
                            value == null ? 'Choose a department' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: permissionProfileId,
                        decoration: const InputDecoration(
                          labelText: 'Permission profile',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final profile in availableProfiles)
                            DropdownMenuItem(
                              value: profile['id'] as String,
                              child: Text(profile['name'] as String),
                            ),
                        ],
                        onChanged: saving || departmentId == null
                            ? null
                            : (value) => setDialogState(
                                () => permissionProfileId = value,
                              ),
                        validator: (value) => value == null
                            ? 'Create and choose a permission profile'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'Create a department and permission profile first. '
                          'The account will receive that profile’s access.',
                          style: TextStyle(color: _muted, height: 1.4),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        _AuthErrorMessage(error!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving ? null : submit,
                child: Text(saving ? 'Creating…' : 'Create staff account'),
              ),
            ],
          );
        },
      ),
    );
    final createdEmail = emailController.text.trim();
    emailController.dispose();
    passwordController.dispose();
    if (created == true && context.mounted) {
      await _loadEmployeeManagement();
      messenger.showSnackBar(
        SnackBar(content: Text('Staff account created for $createdEmail.')),
      );
    }
  }

  Future<void> _editStaffAccess(Map<String, dynamic> member) async {
    String? departmentId = member['department_id'] as String?;
    String? permissionProfileId = member['permission_profile_id'] as String?;
    var saving = false;
    String? error;
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableProfiles = _staffPermissionProfiles
              .where((profile) => profile['department_id'] == departmentId)
              .toList(growable: false);
          if (!availableProfiles.any(
            (profile) => profile['id'] == permissionProfileId,
          )) {
            permissionProfileId = null;
          }
          return AlertDialog(
            title: Text('Edit access · ${member['email']}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: departmentId,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final department in _staffDepartments)
                        DropdownMenuItem(
                          value: department['id'] as String,
                          child: Text(department['name'] as String),
                        ),
                    ],
                    onChanged: saving
                        ? null
                        : (value) => setDialogState(() {
                            departmentId = value;
                            permissionProfileId = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: permissionProfileId,
                    decoration: const InputDecoration(
                      labelText: 'Permission profile',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final profile in availableProfiles)
                        DropdownMenuItem(
                          value: profile['id'] as String,
                          child: Text(profile['name'] as String),
                        ),
                    ],
                    onChanged: saving || departmentId == null
                        ? null
                        : (value) => setDialogState(
                            () => permissionProfileId = value,
                          ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    _AuthErrorMessage(error!),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (departmentId == null ||
                            permissionProfileId == null) {
                          setDialogState(
                            () => error =
                                'Choose a department and permission profile.',
                          );
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await _callStaffFunction('update-staff-access', {
                            'user_id': member['user_id'],
                            'department_id': departmentId,
                            'permission_profile_id': permissionProfileId,
                          });
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } on FunctionException catch (exception) {
                          if (dialogContext.mounted) {
                            setDialogState(
                              () => error = _staffFunctionFailure(exception),
                            );
                          }
                        } on Exception catch (exception) {
                          if (dialogContext.mounted) {
                            setDialogState(
                              () => error = 'Could not update staff access: $exception',
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save access'),
              ),
            ],
          );
        },
      ),
    );
    if (updated == true) await _loadEmployeeManagement();
  }

  Widget _buildStaffPermissionSection(
    int sectionIndex,
    Map<String, Set<String>> selectedPermissions,
    StateSetter setDialogState,
    bool isSubmitting, {
    String? titlePrefix,
  }) {
    final section = _StaffDashboardPageState._sections[sectionIndex];
    final selected = selectedPermissions[section.key] ?? <String>{};
    final allSelected = selected.contains('*');
    final subcards = _StaffDashboardPageState._subcards[sectionIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE4EAF1)),
      ),
      child: ExpansionTile(
        key: PageStorageKey('staff-permission-${section.key}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          titlePrefix ?? section.title,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          allSelected
              ? 'All cards'
              : selected.isEmpty
              ? 'No access assigned'
              : '${selected.length} card(s) selected',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        children: [
          CheckboxListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            activeColor: const Color(0xFF2463EB),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('All section cards'),
            value: allSelected,
            onChanged: isSubmitting
                ? null
                : (checked) => setDialogState(() {
                    if (checked == true) {
                      selectedPermissions[section.key] = {'*'};
                    } else {
                      selectedPermissions.remove(section.key);
                    }
                  }),
          ),
          for (final subcard in subcards)
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              activeColor: const Color(0xFF2463EB),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(subcard),
              value: allSelected || selected.contains(_permissionSlug(subcard)),
              onChanged: isSubmitting || allSelected
                  ? null
                  : (checked) => setDialogState(() {
                      final sectionSelection = selectedPermissions.putIfAbsent(
                        section.key,
                        () => <String>{},
                      );
                      final subcardKey = _permissionSlug(subcard);
                      if (checked == true) {
                        sectionSelection.add(subcardKey);
                      } else {
                        sectionSelection.remove(subcardKey);
                      }
                      if (sectionSelection.isEmpty) {
                        selectedPermissions.remove(section.key);
                      }
                    }),
            ),
        ],
      ),
    );
  }

  Widget _employeeManagementPanel() {
    String departmentName(Object? id) {
      for (final department in _staffDepartments) {
        if (department['id'] == id) return department['name'] as String;
      }
      return 'No department';
    }

    String permissionProfileName(Object? id) {
      for (final profile in _staffPermissionProfiles) {
        if (profile['id'] == id) return profile['name'] as String;
      }
      return 'No permission profile';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Employee workspace',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Set up departments and reusable access profiles first, then create '
          'staff accounts. You can change a staff member’s department and '
          'permissions at any time.',
          style: TextStyle(color: _muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => _saveDepartment(),
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Add department'),
            ),
            OutlinedButton.icon(
              onPressed: _staffDepartments.isEmpty
                  ? null
                  : () => _savePermissionProfile(),
              icon: const Icon(Icons.checklist_outlined),
              label: const Text('Create permission profile'),
            ),
            OutlinedButton.icon(
              onPressed: _staffDepartments.isEmpty ||
                      _staffPermissionProfiles.isEmpty
                  ? null
                  : _addStaffUser,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add staff account'),
            ),
            IconButton(
              tooltip: 'Refresh employee management',
              onPressed: _isLoadingEmployeeData
                  ? null
                  : () => unawaited(_loadEmployeeManagement()),
              icon: _isLoadingEmployeeData
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_employeeManagementError != null) ...[
          const SizedBox(height: 12),
          _AuthErrorMessage(_employeeManagementError!),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _isLoadingEmployeeData
                  ? null
                  : () => unawaited(_loadEmployeeManagement()),
              child: const Text('Retry loading employee data'),
            ),
          ),
        ],
        if (_isLoadingEmployeeData &&
            _staffDepartments.isEmpty &&
            _employeeManagementError == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        const SizedBox(height: 12),
        _employeeGroupHeading(
          'Departments',
          '${_staffDepartments.length} department(s)',
        ),
        if (_staffDepartments.isEmpty)
          _employeeEmptyHint(
            'No departments yet. Add a department before creating a '
            'permission profile or staff account.',
          ),
        for (final department in _staffDepartments)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.apartment_outlined),
              ),
              title: Text(department['name'] as String),
              subtitle: Text(
                '${_staffPermissionProfiles.where((profile) => profile['department_id'] == department['id']).length} permission profile(s)',
              ),
              trailing: IconButton(
                tooltip: 'Edit ${department['name']}',
                onPressed: () => _saveDepartment(department: department),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        const SizedBox(height: 18),
        _employeeGroupHeading(
          'Permission profiles',
          '${_staffPermissionProfiles.length} profile(s)',
        ),
        if (_staffDepartments.isNotEmpty &&
            _staffPermissionProfiles.isEmpty)
          _employeeEmptyHint(
            'Create a profile for each role or access level, such as “Cashier” '
            'or “Kitchen staff”. Choose exactly which sections and cards it '
            'can open.',
          ),
        for (final profile in _staffPermissionProfiles)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings_outlined),
              ),
              title: Text(profile['name'] as String),
              subtitle: Text(
                '${departmentName(profile['department_id'])} · '
                '${(profile['permissions'] as List? ?? const []).length} access grant(s)',
              ),
              trailing: IconButton(
                tooltip: 'Edit ${profile['name']}',
                onPressed: () =>
                    _savePermissionProfile(permissionProfile: profile),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
        const SizedBox(height: 18),
        _employeeGroupHeading('Staff accounts', '${_staffMembers.length} account(s)'),
        if (_staffMembers.isEmpty)
          _employeeEmptyHint(
            _staffPermissionProfiles.isEmpty
                ? 'Create a department and permission profile before adding '
                    'your first staff account.'
                : 'No staff accounts have been created yet.',
          ),
        for (final member in _staffMembers)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(member['email'] as String? ?? 'Staff account'),
              subtitle: Text(
                '${departmentName(member['department_id'])} · '
                '${permissionProfileName(member['permission_profile_id'])}',
              ),
              trailing: IconButton(
                tooltip: 'Edit staff access',
                onPressed: _staffDepartments.isEmpty ||
                        _staffPermissionProfiles.isEmpty
                    ? null
                    : () => _editStaffAccess(member),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
      ],
    );
  }

  Widget _employeeGroupHeading(String title, String count) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        Text(count, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    ),
  );

  Widget _employeeEmptyHint(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE5EAF0)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: const TextStyle(color: _muted, height: 1.45)),
  );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FB),
      drawer: Drawer(child: _navigationPanel()),
      bottomNavigationBar: isWide ? null : _mobileNavigationBar(),
      appBar: AppBar(
        backgroundColor: _deepNavy,
        foregroundColor: Colors.white,
        title: MediaQuery.sizeOf(context).width < 600
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Gelye Sherane',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Café & Restaurant · Management',
                    style: TextStyle(fontSize: 11, color: Color(0xFFD8E2F0)),
                  ),
                ],
              )
            : const Text('Gelye Sherane · Management System'),
        actions: [
          IconButton(
            tooltip: 'Refresh live records',
            onPressed: _isLoadingRecords
                ? null
                : () => unawaited(_loadWorkspaceRecords()),
            icon: _isLoadingRecords
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
          if (_hasSectionAccess(8))
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => setState(() {
                _selectedIndex = 8;
                _selectedSubcard = null;
              }),
              icon: const Icon(Icons.notifications_none_outlined),
            ),
          if (widget.role == 'admin')
            IconButton(
              tooltip: 'Employee workspace',
              onPressed: () => setState(() {
                _selectedIndex = 6;
                _selectedSubcard = null;
              }),
              icon: const Icon(Icons.groups_outlined),
            ),
          if (MediaQuery.sizeOf(context).width >= 600)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  '${widget.email} · ${widget.role == 'admin' ? 'Admin' : 'Staff'}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showSidebar = constraints.maxWidth >= 900;
          final sectionContent = _sectionContent(_selectedIndex);
          if (showSidebar) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 280,
                  child: _navigationPanel(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _contentArea(sectionContent)),
              ],
            );
          }
          return _contentArea(sectionContent);
        },
      ),
    );
  }

  Widget _mobileNavigationBar() {
    const primarySections = [0, 1, 3, 2];
    final visiblePrimary = primarySections
        .where(_hasSectionAccess)
        .toList(growable: false);
    final selectedPrimary = visiblePrimary.indexOf(_selectedIndex);
    final moreDestination = visiblePrimary.length;
    return SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: selectedPrimary < 0 ? moreDestination : selectedPrimary,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE7F0FF),
        destinations: [
          for (final sectionIndex in visiblePrimary)
            NavigationDestination(
              icon: Icon(_primarySectionIcon(sectionIndex, selected: false)),
              selectedIcon: Icon(
                _primarySectionIcon(sectionIndex, selected: true),
              ),
              label: _primarySectionLabel(sectionIndex),
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
        onDestinationSelected: (destination) {
          if (destination == moreDestination) {
            _openMoreSections();
            return;
          }
          setState(() {
            _selectedIndex = visiblePrimary[destination];
            _selectedSubcard = null;
          });
        },
      ),
    );
  }

  String _primarySectionLabel(int sectionIndex) => switch (sectionIndex) {
    0 => 'Home',
    1 => 'Tables',
    3 => 'Kitchen',
    2 => 'Payments',
    _ => _sections[sectionIndex].title,
  };

  IconData _primarySectionIcon(int sectionIndex, {required bool selected}) =>
      switch (sectionIndex) {
        0 => selected ? Icons.home : Icons.home_outlined,
        1 => selected ? Icons.table_restaurant : Icons.table_restaurant_outlined,
        3 => selected ? Icons.soup_kitchen : Icons.soup_kitchen_outlined,
        2 => selected ? Icons.payments : Icons.payments_outlined,
        _ => _sections[sectionIndex].icon,
      };

  Widget _navigationPanel() {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Text(
                'Management sections',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _visibleSectionIndices.length,
                itemBuilder: (context, visibleIndex) {
                  final index = _visibleSectionIndices[visibleIndex];
                  final section = _sections[index];
                  final selected = index == _selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    child: ListTile(
                      key: ValueKey('management-section-$index'),
                      selected: selected,
                      selectedTileColor: const Color(0xFFFFF5E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        section.icon,
                        color: selected ? _gold : _muted,
                      ),
                      title: Text(
                        section.title,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                          _selectedSubcard = null;
                        });
                        _scaffoldKey.currentState?.closeDrawer();
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${widget.email}\n${widget.role == 'admin' ? 'Administrator' : 'Staff'}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contentArea(Widget content) {
    return SelectionArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_signOutError != null) ...[
                  _AuthErrorMessage(_signOutError!),
                  const SizedBox(height: 16),
                ],
                content,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionContent(int index) {
    final section = _sections[index];
    final subcard = _selectedSubcard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subcard != null)
          TextButton.icon(
            onPressed: () => setState(() => _selectedSubcard = null),
            icon: const Icon(Icons.arrow_back),
            label: Text('Back to ${section.title}'),
          ),
        Text(
          subcard ??
              (index == 0
                  ? (widget.role == 'admin'
                            ? 'Administrator Dashboard'
                            : 'Staff Dashboard')
                      : index == 2
                      ? 'Payments & Finance'
                      : section.title),
          style: TextStyle(
            fontSize: MediaQuery.sizeOf(context).width < 600 ? 24 : 30,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        if (index == 2)
          Text(
            subcard == null
                ? 'View and manage all financial operations.'
                : 'Live workspace records for $subcard.',
            style: const TextStyle(color: _muted, height: 1.5),
          )
        else if (index != 0)
          Text(
            subcard == null
                ? section.description
                : 'Details for $subcard in ${section.title}.',
            style: const TextStyle(color: _muted, height: 1.5),
          ),
        if (index != 0 && index != 2) const SizedBox(height: 20),
        if (widget.permissionsLoadError != null)
          _AuthErrorMessage(
            'Could not load section permissions. Dashboard is open, but no '
            'additional sections or cards are shown: ${widget.permissionsLoadError}',
          )
        else if (widget.role == 'staff' &&
            widget.grantedPermissions.isEmpty)
          const _AuthErrorMessage(
            'No additional sections or dashboard cards are assigned yet. '
            'Ask an administrator to update this account.',
          ),
        if (widget.permissionsLoadError != null ||
            (widget.role == 'staff' && widget.grantedPermissions.isEmpty))
          const SizedBox(height: 16),
        if (index != 0 && index != 2) ...[
          _workspaceConnectionBanner(),
          const SizedBox(height: 20),
        ],
        if (index == 6 && widget.role == 'admin' && subcard == null)
          _employeeManagementPanel()
        else if (index == 2 && subcard != null)
          _financeDetail(section, subcard)
        else if (subcard == null)
          _sectionSubcardGrid(index)
        else
          _subcardDetail(section, subcard),
        const SizedBox(height: 20),
        Text(
          'Signed in as ${widget.email}',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _workspaceConnectionBanner() {
    final connected = _workspaceError == null && !_isLoadingRecords;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFFEAF5EC)
            : const Color(0xFFFFF1DD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: connected
              ? const Color(0xFFB8D9BD)
              : const Color(0xFFEBD7AC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            color: connected ? const Color(0xFF27753A) : _ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isLoadingRecords
                  ? 'Connecting to live Supabase records...'
                  : _workspaceError ??
                        'Connected to live Supabase records. Updates sync '
                        'automatically across authorized sections.',
              style: TextStyle(
                color: connected ? const Color(0xFF215D30) : _ink,
                height: 1.45,
              ),
            ),
          ),
          if (_workspaceError != null)
            TextButton(
              onPressed: () => unawaited(_loadWorkspaceRecords()),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Widget _sectionSubcardGrid(int sectionIndex) {
    if (sectionIndex == 0) return _dashboardLayout();
    final visibleSubcards = _visibleSubcards(sectionIndex);
    if (visibleSubcards.isEmpty) {
      return const Text('No cards in this section are assigned to this account.');
    }
    if (sectionIndex == 2) {
      return _paymentManagementOverview(visibleSubcards);
    }
    final featuredCards = _featuredSectionCards[sectionIndex];
    if (featuredCards != null) {
      final primaryCards = visibleSubcards
          .where(featuredCards.contains)
          .toList(growable: false);
      final additionalCards = visibleSubcards
          .where((title) => !featuredCards.contains(title))
          .toList(growable: false);
      if (primaryCards.isNotEmpty && additionalCards.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _managementCardGrid(
              sectionIndex: sectionIndex,
              titles: primaryCards,
              columns: sectionIndex == 1 ? 2 : null,
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                title: Text('More cards (${additionalCards.length})'),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  _managementCardGrid(
                    sectionIndex: sectionIndex,
                    titles: additionalCards,
                  ),
                ],
              ),
            ),
          ],
        );
      }
      if (primaryCards.isNotEmpty) {
        return _managementCardGrid(
          sectionIndex: sectionIndex,
          titles: primaryCards,
          columns: sectionIndex == 1 ? 2 : null,
        );
      }
    }
    return _managementCardGrid(
      sectionIndex: sectionIndex,
      titles: visibleSubcards,
      columns: sectionIndex == 1 ? 2 : null,
    );
  }

  Widget _managementCardGrid({
    required int sectionIndex,
    required List<String> titles,
    int? columns,
    String? revenueCard,
    double? revenue,
    bool revenueUnavailable = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount =
            columns ??
            (constraints.maxWidth >= 1120
                ? 4
                : constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 600
                ? 2
                : 1);
        final cardWidth =
            (constraints.maxWidth - (columnCount - 1) * 12) / columnCount;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final title in titles)
              SizedBox(
                width: cardWidth,
                child: _managementCard(
                  sectionIndex,
                  title,
                  revenue: title == revenueCard ? revenue : null,
                  revenueUnavailable:
                      title == revenueCard && revenueUnavailable,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dashboardLayout() {
    final assignedCards = _visibleSubcards(0);
    if (assignedCards.isEmpty) {
      return Text(
        widget.permissionsLoadError == null
            ? 'No dashboard cards are assigned to this account.'
            : 'Dashboard cards are unavailable until permissions can be loaded.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateRangeControls(),
        const SizedBox(height: 12),
        for (final group in _dashboardGroups)
          _dashboardGroup(
            group,
            assignedCards
                .where(group.cards.contains)
                .toList(growable: false),
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1DD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                _workspaceError == null
                    ? Icons.cloud_done_outlined
                    : Icons.warning_amber_rounded,
                color: _workspaceError == null
                    ? const Color(0xFF27753A)
                    : const Color(0xFF9A5B00),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _workspaceError ??
                      'Live records are shared across the workspace. '
                          'No card processor is connected.',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Quick Links',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final link in [
              (label: 'Tables', index: 1, icon: Icons.table_restaurant_outlined),
              (label: 'Kitchen', index: 3, icon: Icons.soup_kitchen_outlined),
              (label: 'Payments', index: 2, icon: Icons.payments_outlined),
            ].where((link) => _hasSectionAccess(link.index)))
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _selectedIndex = link.index;
                  _selectedSubcard = null;
                }),
                icon: Icon(link.icon),
                label: Text(link.label),
              ),
          ],
        ),
      ],
    );
  }

  static const _dashboardGroups = [
    (
      title: 'Payments & Finance',
      icon: Icons.payments_outlined,
      tint: Color(0xFFDDF7EC),
      iconColor: Color(0xFF138052),
      cards: [
        'Today Revenue',
        'Standing Cash',
        'Pending Payment',
        'Invoices',
        'Discounts',
        'Credit Accounts',
        'Cash Reconciliation',
      ],
    ),
    (
      title: 'Tables & Reservations',
      icon: Icons.table_restaurant_outlined,
      tint: Color(0xFFE5EEFF),
      iconColor: Color(0xFF2463D3),
      cards: [
        'Tables Occupied',
        'Table Map',
        'Reservations',
        'Cleaning Needed',
        'Service Speed',
        'Guests Today',
        'Table Occupancy',
      ],
    ),
    (
      title: 'Kitchen & Orders',
      icon: Icons.soup_kitchen_outlined,
      tint: Color(0xFFFFEBD1),
      iconColor: Color(0xFFB75B11),
      cards: [
        'Kitchen Orders',
        'Menu',
        'Low Stock',
        'Nargile Orders',
        'Motel Orders',
        'Online Orders',
        'Today Orders',
        'Kitchen Queue',
        'Takeaway & Delivery',
      ],
    ),
    (
      title: 'Management & Operations',
      icon: Icons.groups_outlined,
      tint: Color(0xFFF0E4FF),
      iconColor: Color(0xFF7638BC),
      cards: [
        'Customers',
        'Employees',
        'Tasks',
        'Events',
        'Feedback',
        'Maintenance',
        'Tourism Customers',
        'Customer Requests',
        'Attendance',
      ],
    ),
    (
      title: 'Reports, Settings & Security',
      icon: Icons.bar_chart_outlined,
      tint: Color(0xFFDFF5F6),
      iconColor: Color(0xFF117D84),
      cards: [
        'Reports',
        'Security',
        'Backup',
        'Offline Mode',
        'System Health',
        'Audit & Activity',
        'Product Performance',
        'Personalization',
      ],
    ),
  ];

  Widget _dashboardGroup(
    ({
      String title,
      IconData icon,
      Color tint,
      Color iconColor,
      List<String> cards,
    }) group,
    List<String> visibleCards,
  ) {
    if (visibleCards.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1209243A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: group.tint.withValues(alpha: 0.55),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: group.iconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(group.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'See all (${visibleCards.length})',
                style: TextStyle(
                  color: group.iconColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          children: [
            _compactMetricGrid(
              sectionIndex: 0,
              titles: visibleCards,
              height: 118,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRangeControls() {
    final dateLabel =
        '${_selectedReportDate.day}/${_selectedReportDate.month}/${_selectedReportDate.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedReportDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null && mounted) {
              setState(() {
                _selectedReportDate = date;
                _selectedDateRange = 'Today';
              });
            }
          },
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text('$dateLabel · $_selectedDateRange'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE3E8F0)),
          ),
        ),
        const SizedBox(height: 9),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final range in const [
                'Today',
                'Yesterday',
                'This Week',
                'This Month',
                'This Year',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(range),
                    selected: _selectedDateRange == range,
                    onSelected: (_) =>
                        setState(() => _selectedDateRange = range),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentManagementOverview(List<String> titles) {
    const featuredFinanceCards = [
      'Today Revenue',
      'Standing Cash',
      'Pending Payments',
      'Collected Cash',
      'Available Cash',
      'Cash Over / Short',
      'Expenses',
      'Invoices & Payments',
      'Table Income',
      'Refunds & Voids',
      'Confirm Credit',
    ];
    final featuredCards = [
      for (final title in featuredFinanceCards)
        if (titles.contains(title)) title,
    ];
    final additionalCards = titles
        .where((title) => !featuredFinanceCards.contains(title))
        .toList(growable: false);
    final allRecords = _recordsInSelectedRange(
      _workspaceRecords.where((record) => record.sectionKey == 'payment_management'),
    );
    final recordedAmounts = allRecords
        .where((record) => record.amount != null)
        .fold<double>(0, (total, record) => total + record.amount!);
    final openCount = allRecords
        .where((record) => record.status == 'open' || record.status == 'in_progress')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dateRangeControls(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4E6FA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_done_outlined, color: Color(0xFF2570B8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _workspaceError != null
                      ? 'Finance data unavailable: $_workspaceError'
                      : _isLoadingRecords
                      ? 'Loading finance records…'
                      : '${allRecords.length} tracked record(s) · $openCount open · '
                                '${allRecords.any((record) => record.amount != null) ? '${recordedAmounts.toStringAsFixed(0)} IQD' : '—'} recorded',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _workspaceError == null
                      ? const Color(0xFFDDF7EC)
                      : const Color(0xFFFFE8E6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _workspaceError == null ? 'Live' : 'Unavailable',
                  style: TextStyle(
                    color: _workspaceError == null
                        ? const Color(0xFF138052)
                        : const Color(0xFFB42318),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _compactMetricGrid(
          sectionIndex: 2,
          titles: featuredCards,
          height: 150,
        ),
        if (additionalCards.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: Text('More finance cards (${additionalCards.length})'),
              childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: [
                _compactMetricGrid(
                  sectionIndex: 2,
                  titles: additionalCards,
                  height: 150,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _compactMetricGrid({
    required int sectionIndex,
    required List<String> titles,
    required double height,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 460
            ? 3
            : constraints.maxWidth < 760
            ? 3
            : constraints.maxWidth < 1120
            ? 3
            : 4;
        final spacing = 8.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < titles.length; index++)
              SizedBox(
                width: width,
                height: height,
                child: _compactMetricCard(
                  sectionIndex: sectionIndex,
                  title: titles[index],
                  index: index,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _compactMetricCard({
    required int sectionIndex,
    required String title,
    required int index,
  }) {
    const colors = [
      (background: Color(0xFFEAF8F0), accent: Color(0xFF17864D)),
      (background: Color(0xFFFFF5DC), accent: Color(0xFFC77A12)),
      (background: Color(0xFFFFEDF1), accent: Color(0xFFD7355D)),
      (background: Color(0xFFF2EAFE), accent: Color(0xFF7436C8)),
      (background: Color(0xFFEAF4FF), accent: Color(0xFF2463D3)),
      (background: Color(0xFFE5F8F7), accent: Color(0xFF148A8F)),
    ];
    final palette = colors[index % colors.length];
    final section = _sections[sectionIndex];
    final records = _recordsInSelectedRange(
      _recordsFor(section.key, _permissionSlug(title)),
    );
    final amountRecords = records.where((record) => record.amount != null);
    final recordedAmount = amountRecords.fold<double>(
      0,
      (total, record) => total + record.amount!,
    );
    final currency = amountRecords.isEmpty ? 'IQD' : amountRecords.first.currency;
    final unavailable = _workspaceError != null;
    final isLoading = _isLoadingRecords;
    final primary = unavailable
        ? '—'
        : isLoading
        ? '…'
        : records.isEmpty
        ? '—'
        : amountRecords.isNotEmpty
        ? '${recordedAmount.toStringAsFixed(0)} $currency'
        : '${records.length}';
    final supporting = unavailable
        ? 'Unavailable'
        : isLoading
        ? 'Loading live data'
        : records.isEmpty
        ? 'No records'
        : amountRecords.isNotEmpty
        ? '${records.length} tracked record(s)'
        : records.length == 1
        ? '1 tracked record'
        : 'Tracked records';
    return Card(
      margin: EdgeInsets.zero,
      color: palette.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.accent.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          if (sectionIndex == 2) {
            _financeSearch = '';
            _financeStatusFilter = 'All';
          }
          _selectedSubcard = title;
        }),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _metricIcon(title, section.icon),
                      color: palette.accent,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: palette.accent,
                    size: 19,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                primary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unavailable ? _muted : palette.accent,
                  fontSize: sectionIndex == 0 ? 14 : 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                supporting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _metricIcon(String title, IconData fallback) => switch (title) {
    'Today Revenue' || 'Revenue' => Icons.bar_chart_rounded,
    'Standing Cash' || 'Available Cash' => Icons.account_balance_wallet_outlined,
    'Pending Payment' || 'Pending Payments' => Icons.schedule_rounded,
    'Invoices' || 'Invoices & Payments' => Icons.receipt_long_outlined,
    'Collected Cash' || 'Cash/Card/Online' => Icons.payments_outlined,
    'Cash Over / Short' => Icons.balance_outlined,
    'Discounts' => Icons.sell_outlined,
    'Credit Accounts' || 'Confirm Credit' => Icons.credit_score_outlined,
    'Tables Occupied' || 'Table Occupancy' => Icons.chair_alt_outlined,
    'Current Customers' || 'Customers' => Icons.people_outline,
    'Active Tables' || "Today's Tables" => Icons.table_restaurant_outlined,
    "Today's Customers" => Icons.groups_outlined,
    'Table Status' => Icons.grid_view_rounded,
    'Table Map' || 'Visual Table Map' => Icons.map_outlined,
    'Reservations' => Icons.calendar_month_outlined,
    'Waiting List' => Icons.access_time_outlined,
    'Cleaning Needed' || 'Cleaning' || 'Table Cleaning' =>
      Icons.cleaning_services_outlined,
    'Table Requests' => Icons.notifications_active_outlined,
    'Table Performance' || 'Service Speed' => Icons.bar_chart_rounded,
    'Kitchen Orders' || 'Kitchen Queue' || 'Table Orders' =>
      Icons.soup_kitchen_outlined,
    'Menu' || 'Menu Categories' || 'Menu Management' =>
      Icons.restaurant_menu_outlined,
    'Low Stock' || 'Inventory' || 'Inventory & Stock' =>
      Icons.inventory_2_outlined,
    'Nargile Management' || 'Nargile' => Icons.smoking_rooms_outlined,
    'Preparation Time' => Icons.timer_outlined,
    'Kitchen Devices' || 'Devices & Printers' => Icons.print_outlined,
    'Online Orders' => Icons.language_outlined,
    'Motel Orders' => Icons.hotel_outlined,
    'Takeaway & Delivery' => Icons.delivery_dining_outlined,
    'Reports & Analytics' => Icons.query_stats_outlined,
    'System Health' => Icons.monitor_heart_outlined,
    'Security Center' => Icons.shield_outlined,
    'Permissions & Roles' => Icons.admin_panel_settings_outlined,
    'Audit & Activity History' => Icons.history_outlined,
    'Backup & Restore' => Icons.backup_outlined,
    'Offline & Sync' => Icons.sync_outlined,
    'System Updates' => Icons.system_update_alt_outlined,
    'Settings & Configuration' => Icons.settings_outlined,
    'Customers' || 'Customer Directory' => Icons.people_outline,
    'Employees' || 'Staff Directory' => Icons.badge_outlined,
    'Tasks' => Icons.task_alt_outlined,
    'Events' => Icons.event_outlined,
    'Reports' || 'Revenue Reports' => Icons.query_stats_outlined,
    'Security' => Icons.shield_outlined,
    'Backup' => Icons.backup_outlined,
    'Offline Mode' => Icons.wifi_off_outlined,
    'Expenses' || 'Costs & Expenses' => Icons.receipt_long_outlined,
    'Refunds & Voids' || 'Refunds' => Icons.undo_rounded,
    'Table Income' => Icons.table_restaurant_outlined,
    _ => fallback,
  };

  Widget _financeDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    final subcardKey = _permissionSlug(subcard);
    final canManage =
        widget.role == 'admin' ||
        widget.grantedPermissions.contains('${section.key}:*') ||
        widget.grantedPermissions.contains('${section.key}:$subcardKey');
    final records = _recordsInSelectedRange(
      _recordsFor(section.key, subcardKey),
    );
    final matchingRecords = records.where((record) {
      final matchesStatus =
          _financeStatusFilter == 'All' ||
          record.status == _financeStatusFilter.toLowerCase().replaceAll(' ', '_');
      final query = _financeSearch.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          record.title.toLowerCase().contains(query) ||
          record.details.toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList(growable: false);
    final amountRecords = records.where((record) => record.amount != null);
    final amountTotal = amountRecords.fold<double>(
      0,
      (total, record) => total + record.amount!,
    );
    final openCount = records
        .where((record) => record.status == 'open' || record.status == 'in_progress')
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _dateRangeControls()),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _workspaceError == null
                    ? const Color(0xFFE1F6EA)
                    : const Color(0xFFFFE8E6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _workspaceError == null ? '● Live' : 'Unavailable',
                style: TextStyle(
                  color: _workspaceError == null
                      ? const Color(0xFF167344)
                      : const Color(0xFFB42318),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _financeSummaryCard(
              icon: Icons.receipt_long_outlined,
              label: 'Tracked records',
              value: _isLoadingRecords ? '…' : '${records.length}',
              tint: const Color(0xFFEAF2FF),
              accent: const Color(0xFF2563D9),
            ),
            _financeSummaryCard(
              icon: Icons.payments_outlined,
              label: 'Recorded amount',
              value: amountRecords.isEmpty
                  ? '—'
                  : '${amountTotal.toStringAsFixed(0)} ${amountRecords.first.currency}',
              tint: const Color(0xFFE8F8EF),
              accent: const Color(0xFF16814A),
            ),
            _financeSummaryCard(
              icon: Icons.schedule_outlined,
              label: 'Open records',
              value: '$openCount',
              tint: const Color(0xFFFFF2D8),
              accent: const Color(0xFFB9670C),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE1E7EF)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$subcard records',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canManage)
                    FilledButton.icon(
                      onPressed: _isLoadingRecords
                          ? null
                          : () => _createWorkspaceRecord(section, subcard),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add record'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => setState(() => _financeSearch = value),
                decoration: InputDecoration(
                  hintText: 'Search $subcard...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF6F8FB),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final status in const [
                      'All',
                      'Open',
                      'In progress',
                      'Completed',
                      'Cancelled',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: _financeStatusFilter == status,
                          onSelected: (_) =>
                              setState(() => _financeStatusFilter = status),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (_workspaceError != null)
                _AuthErrorMessage(_workspaceError!)
              else if (_isLoadingRecords)
                const Center(child: CircularProgressIndicator())
              else if (matchingRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 34,
                          color: Colors.blueGrey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          records.isEmpty
                              ? 'No live records for this date range.'
                              : 'No records match these filters.',
                          style: const TextStyle(color: _muted),
                        ),
                        if (canManage && records.isEmpty) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Add a record to begin tracking this card.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                for (final record in matchingRecords)
                  _financeRecordTile(record, canManage: canManage),
              if (amountRecords.isNotEmpty) ...[
                const Divider(height: 22),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'Tracked amount total · ${amountTotal.toStringAsFixed(0)} ${amountRecords.first.currency}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'Totals include only records saved in this workspace. They are '
                'not reconciled against a payment provider or cash register.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _financeSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color tint,
    required Color accent,
  }) => Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _financeRecordTile(
    CafeWorkspaceRecord record, {
    required bool canManage,
  }) {
    final statusColor = switch (record.status) {
      'completed' => const Color(0xFF16814A),
      'cancelled' => const Color(0xFFB42318),
      'in_progress' => const Color(0xFF2563D9),
      _ => const Color(0xFFB9670C),
    };
    return Container(
      key: ValueKey('finance-record-${record.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6EBF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF2563D9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Updated ${record.updatedAt.toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (record.amount != null)
                Text(
                  '${record.amount!.toStringAsFixed(0)} ${record.currency}',
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Record actions',
                  onSelected: (action) {
                    if (action == 'delete') {
                      unawaited(_deleteWorkspaceRecord(record));
                    } else {
                      unawaited(_updateRecordStatus(record, action));
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'open', child: Text('Mark open')),
                    PopupMenuItem(
                      value: 'in_progress',
                      child: Text('Mark in progress'),
                    ),
                    PopupMenuItem(
                      value: 'completed',
                      child: Text('Mark completed'),
                    ),
                    PopupMenuItem(
                      value: 'cancelled',
                      child: Text('Mark cancelled'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete record'),
                    ),
                  ],
                ),
            ],
          ),
          if (record.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(record.details, style: const TextStyle(color: _muted)),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              record.status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _managementCard(
    int sectionIndex,
    String title, {
    double? revenue,
    bool revenueUnavailable = false,
  }) {
    final section = _sections[sectionIndex];
    final isRevenueCard = sectionIndex == 0 && title == _subcards.first.first;
    final subcardKey = _permissionSlug(title);
    final records = _recordsFor(section.key, subcardKey);
    const cardPalettes = [
      (background: Color(0xFFE0F6EF), accent: Color(0xFF12805B)),
      (background: Color(0xFFE6F0FF), accent: Color(0xFF2363D4)),
      (background: Color(0xFFF1E8FF), accent: Color(0xFF7638BC)),
      (background: Color(0xFFFFF0DC), accent: Color(0xFFB75B11)),
      (background: Color(0xFFE4F5F5), accent: Color(0xFF117D84)),
      (background: Color(0xFFFFEAF0), accent: Color(0xFFD7355D)),
    ];
    final paletteTitles =
        _featuredSectionCards[sectionIndex] ?? _subcards[sectionIndex];
    final paletteIndex = paletteTitles.indexOf(title);
    final palette = cardPalettes[
      (paletteIndex < 0 ? 0 : paletteIndex) % cardPalettes.length
    ];
    final recordCountLabel = _isLoadingRecords
        ? 'Connecting...'
        : _workspaceError != null
        ? 'Unavailable'
        : records.isEmpty
        ? '0 tracked records'
        : '${records.length} record${records.length == 1 ? '' : 's'}';
    final primaryText = isRevenueCard
        ? revenueUnavailable
              ? '— IQD'
              : '${revenue!.toStringAsFixed(0)} IQD'
        : recordCountLabel;
    final secondaryText = isRevenueCard
        ? revenueUnavailable
              ? _connectionLabel(section.key, subcardKey)
              : 'Tracked records only · excludes unrecorded sales'
        : _sectionCardDescriptions[title] ?? 'Live Supabase records';
    return SizedBox(
      height: 176,
      child: Card(
        margin: EdgeInsets.zero,
        color: palette.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.accent.withValues(alpha: 0.14)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _selectedSubcard = title),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _metricIcon(title, section.icon),
                        color: palette.accent,
                        size: 19,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.chevron_right,
                          color: palette.accent,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  secondaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  primaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: revenueUnavailable && isRevenueCard
                        ? _muted
                        : palette.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subcardDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
    final subcardKey = _permissionSlug(subcard);
    final records = _recordsFor(section.key, subcardKey);
    final canManage =
        widget.role == 'admin' ||
        widget.grantedPermissions.contains('${section.key}:*') ||
        widget.grantedPermissions.contains('${section.key}:$subcardKey');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE8E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(section.icon, color: _gold, size: 30),
          const SizedBox(height: 14),
          Text(
            subcard,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _workspaceError ??
                'Live Supabase records for this card. Records and status '
                    'changes are visible to users authorized for this card.',
            style: const TextStyle(color: _muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: Icon(
                  _workspaceError == null
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 18,
                ),
                label: Text(_connectionLabel(section.key, subcardKey)),
              ),
              if (canManage)
                FilledButton.icon(
                  onPressed: _isLoadingRecords
                      ? null
                      : () => _createWorkspaceRecord(section, subcard),
                  icon: const Icon(Icons.add),
                  label: Text('Add $subcard record'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_workspaceError != null)
            _AuthErrorMessage(_workspaceError!)
          else if (_isLoadingRecords)
            const Center(child: CircularProgressIndicator())
          else if (records.isEmpty)
            const Text(
              'No records yet. Add the first record to start tracking this card.',
              style: TextStyle(color: _muted),
            )
          else
            for (final record in records) _workspaceRecordTile(record),
        ],
      ),
    );
  }

  Widget _workspaceRecordTile(CafeWorkspaceRecord record) {
    return Card(
      key: ValueKey('workspace-record-${record.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (record.amount != null)
                  Text(
                    '${record.amount!.toStringAsFixed(2)} ${record.currency}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                IconButton(
                  tooltip: 'Delete ${record.title}',
                  onPressed: () => _deleteWorkspaceRecord(record),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (record.details.isNotEmpty) Text(record.details),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Updated ${record.updatedAt.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
                DropdownButton<String>(
                  value: record.status,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In progress'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                  ],
                  onChanged: (status) {
                    if (status != null && status != record.status) {
                      unawaited(_updateRecordStatus(record, status));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StaffSignInDialog extends StatefulWidget {
  const StaffSignInDialog({
    required this.supabaseConfigured,
    required this.supabaseConfigurationProvided,
    super.key,
  });

  final bool supabaseConfigured;
  final bool supabaseConfigurationProvided;

  @override
  State<StaffSignInDialog> createState() => _StaffSignInDialogState();
}

class _StaffSignInDialogState extends State<StaffSignInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _mfaFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();
  String? _error;
  String? _mfaFactorId;
  String? _mfaEnrollmentSecret;
  bool? _isAdmin;
  bool _mfaPending = false;
  bool _isLoadingRole = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (_signedInEmail != null) {
      unawaited(_continueAuthenticatedSession());
    }
  }

  String? get _signedInEmail =>
      widget.supabaseConfigured
          ? Supabase.instance.client.auth.currentUser?.email
          : null;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _continueAuthenticatedSession() async {
    final auth = Supabase.instance.client.auth;
    final assurance = auth.mfa.getAuthenticatorAssuranceLevel();
    if (assurance.currentLevel == AuthenticatorAssuranceLevels.aal2) {
      if (mounted) setState(() => _mfaPending = false);
      await _loadStaffRole();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _mfaPending = true;
      _error = null;
    });
    try {
      final factors = await auth.mfa.listFactors();
      if (factors.totp.isNotEmpty) {
        setState(() => _mfaFactorId = factors.totp.first.id);
      } else {
        final enrollment = await auth.mfa.enroll(
          factorType: FactorType.totp,
          issuer: 'Gelye Sherane Cafe',
          friendlyName: 'Gelye Sherane staff sign-in',
        );
        final totp = enrollment.totp;
        if (totp == null) {
          throw const AuthException(
            'Supabase did not return authenticator enrollment details.',
          );
        }
        if (!mounted) return;
        setState(() {
          _mfaFactorId = enrollment.id;
          _mfaEnrollmentSecret = totp.secret;
        });
      }
    } on AuthException {
      if (mounted) {
        setState(() {
          _error =
              'Could not set up authenticator verification. Check that '
              'authenticator-app MFA is enabled for this Supabase project.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error =
              'Could not reach the authenticator service. Check your '
              'connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyMfaCode() async {
    if (!_mfaFormKey.currentState!.validate()) return;
    final factorId = _mfaFactorId;
    if (factorId == null) {
      setState(() {
        _error = 'Authenticator setup is missing. Sign out and sign in again.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: _mfaCodeController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _mfaFactorId = null;
        _mfaEnrollmentSecret = null;
        _mfaPending = false;
        _mfaCodeController.clear();
      });
      await _loadStaffRole();
    } on AuthException {
      if (mounted) {
        setState(() {
          _error =
              'That authenticator code was not accepted. Enter the current '
              'six-digit code and try again.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error =
              'Could not verify the authenticator code. Check your '
              'connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _loadStaffRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingRole = true;
      _isAdmin = null;
      _error = null;
    });
    try {
      final profile = await Supabase.instance.client
          .from('staff_profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null) {
        if (!mounted) return;
        setState(() {
          _error =
              'No staff profile exists for this account. Run the staff '
              'migration and admin bootstrap SQL in the Supabase project '
              'configured for this site.';
        });
        return;
      }

      if (!mounted) return;
      final role = profile['role'];
      if (role is! String || (role != 'admin' && role != 'staff')) {
        setState(() {
          _error = 'This account does not have a valid staff role.';
        });
        return;
      }
      final grantedPermissions = <String>{};
      String? permissionsLoadError;
      if (role == 'staff') {
        try {
          final permissionRows = await Supabase.instance.client
              .from('staff_permissions')
              .select('section_key, subcard_key')
              .eq('user_id', user.id);
          for (final row in permissionRows) {
            final sectionKey = row['section_key'];
            final subcardKey = row['subcard_key'];
            if (sectionKey is! String || subcardKey is! String) {
              throw const FormatException(
                'The permission service returned an invalid grant.',
              );
            }
            grantedPermissions.add('$sectionKey:$subcardKey');
          }
        } on PostgrestException catch (exception) {
          permissionsLoadError =
              '(${exception.code ?? 'unknown'}): ${exception.message}';
          grantedPermissions.clear();
        } on Exception catch (exception) {
          permissionsLoadError = exception.toString();
          grantedPermissions.clear();
        }
      }

      if (!mounted) return;
      setState(() {
        _isAdmin = role == 'admin';
      });
      await Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => StaffDashboardPage(
            email: user.email ?? '',
            role: role,
            grantedPermissions: grantedPermissions,
            permissionsLoadError: permissionsLoadError,
          ),
        ),
        (route) => route.isFirst,
      );
    } on PostgrestException catch (exception) {
      if (mounted) {
        setState(() {
          _error =
              'Could not load staff permissions from Supabase '
              '(${exception.code ?? 'unknown'}): ${exception.message}';
        });
      }
    } on Exception catch (exception) {
      if (mounted) {
        setState(() {
          _error = 'Could not open the staff dashboard: $exception';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (response.session == null || response.user == null) {
        setState(() {
          _error = 'Sign-in did not create an authenticated session.';
        });
      } else {
        setState(() {});
        await _continueAuthenticatedSession();
      }
    } on AuthException {
      if (mounted) {
        setState(() {
          _error =
              'Sign-in or authenticator setup failed. Check your credentials '
              'and MFA settings, then try again.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error = 'Could not reach the sign-in service. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        setState(() {
          _isAdmin = null;
          _error = null;
          _mfaFactorId = null;
          _mfaEnrollmentSecret = null;
          _mfaPending = false;
          _mfaCodeController.clear();
        });
      }
    } on AuthException {
      if (mounted) {
        setState(() {
          _error = 'Sign-out failed. Please try again.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error = 'Could not reach the sign-in service. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedInEmail = _signedInEmail;
    return AlertDialog(
      icon: const Icon(Icons.lock_outline, color: _gold),
      title: Text(signedInEmail == null ? 'Staff sign in' : 'Staff account'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: !widget.supabaseConfigured
              ? _configurationMessage()
              : signedInEmail != null
                  ? _mfaPending
                      ? _mfaFactorId != null
                          ? _mfaVerificationForm()
                          : _mfaSetupError()
                      : _signedInContent(signedInEmail)
                  : _signInForm(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : _mfaPending
                  ? _signOut
                  : () => Navigator.of(context).pop(),
          child: Text(
            signedInEmail == null
                ? 'Close'
                : _mfaPending
                    ? 'Sign out'
                    : 'Done',
          ),
        ),
        if (widget.supabaseConfigured &&
            signedInEmail != null &&
            _mfaPending &&
            _mfaFactorId != null)
          FilledButton(
            onPressed: _isSubmitting ? null : _verifyMfaCode,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify code'),
          ),
        if (widget.supabaseConfigured &&
            signedInEmail != null &&
            !_mfaPending)
          FilledButton(
            onPressed: _isSubmitting ? null : _signOut,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign out'),
          ),
        if (widget.supabaseConfigured && signedInEmail == null)
          FilledButton(
            onPressed: _isSubmitting ? null : _signIn,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
      ],
    );
  }

  Widget _configurationMessage() {
    final message = widget.supabaseConfigurationProvided
        ? 'Supabase configuration is incomplete or does not match the approved '
            'project. Check the deployment variables before signing in.'
        : 'Staff sign-in is not configured for this deployment yet. Add the '
            'Supabase project URL, expected project reference, and publishable '
            'key to the deployment settings.';
    return Text(message, style: const TextStyle(height: 1.5));
  }

  Widget _signedInContent(String email) {
    if (_isLoadingRole) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Signed in as $email.'),
        const SizedBox(height: 12),
        if (_isAdmin == true) ...[
          const Text(
            'Administrator access',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Create staff accounts from the management workspace so you can '
            'assign their section and card permissions.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ] else
          const Text(
            'This account does not have an administrator role. The first '
            'administrator must be assigned by the project owner.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _AuthErrorMessage(_error!),
        ],
      ],
    );
  }

  Widget _mfaVerificationForm() {
    return Form(
      key: _mfaFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _mfaEnrollmentSecret == null
                ? 'Enter the current code from your authenticator app.'
                : 'Add this account to an authenticator app, then enter its '
                    'current code to finish setup.',
            style: const TextStyle(color: _muted, height: 1.45),
          ),
          if (_mfaEnrollmentSecret case final secret?) ...[
            const SizedBox(height: 12),
            const Text(
              'Account setup key',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(secret),
            const SizedBox(height: 8),
            const Text(
              'Keep this setup key private. After setup, use the rotating '
              'six-digit code from your authenticator app.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _mfaCodeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Authenticator code',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.security),
              counterText: '',
            ),
            validator: (value) =>
                value == null || !RegExp(r'^\d{6}$').hasMatch(value.trim())
                    ? 'Enter the six-digit authenticator code'
                    : null,
            onFieldSubmitted: (_) =>
                _isSubmitting ? null : _verifyMfaCode(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthErrorMessage(_error!),
          ],
        ],
      ),
    );
  }

  Widget _mfaSetupError() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Authenticator verification is required before staff access. The '
          'authenticator setup could not be prepared. Sign out and try again.',
          style: TextStyle(color: _muted, height: 1.45),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _AuthErrorMessage(_error!),
        ],
      ],
    );
  }

  Widget _signInForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Use your staff account to continue.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Staff email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (!email.contains('@') || !email.contains('.')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.password_outlined),
            ),
            validator: (value) => value == null || value.isEmpty
                ? 'Enter your password'
                : null,
            onFieldSubmitted: (_) => _isSubmitting ? null : _signIn(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _AuthErrorMessage(_error!),
          ],
        ],
      ),
    );
  }
}

class _AuthErrorMessage extends StatelessWidget {
  const _AuthErrorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
