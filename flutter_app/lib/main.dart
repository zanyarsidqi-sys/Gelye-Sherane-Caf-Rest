import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      description: 'Operational command center for the cafe.',
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
      'Today Orders',
      'Table Occupancy',
      'Kitchen Queue',
      'Motel Orders',
      'Tourism Customers',
      'Reservations',
      'Customer Requests',
      'Takeaway & Delivery',
      'Attendance',
      'Cash Reconciliation',
      'Product Performance',
      'Service Speed',
      'Feedback',
      'Maintenance',
      'System Health',
      'Audit & Activity',
      'Personalization',
    ],
    [
      'Table Overview',
      'Visual Table Map',
      'Add/Edit Tables & Chairs',
      'QR Generate/Print/Revoke',
      'Table Orders',
      'Customer QR Screen',
      'Pricing Modes',
      'Reservations',
      'Join/Transfer',
      'Split Bills',
      'Pay for Others',
      'Cleaning',
      'Table History',
      'Extra Chairs',
    ],
    [
      'Revenue',
      'Costs & Expenses',
      'Invoices',
      'Payment Collection',
      'Cash/Card/Online',
      'Standing Cash',
      'Pending Payment',
      'Customer Credit',
      'Discounts',
      'Refunds',
      'Cash Reconciliation',
      'Approvals',
      'Audit',
    ],
    [
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
      'Customer Directory',
      'Motel Orders',
      'Online Orders',
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
      'General',
      'Backup & Restore',
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

  Future<void> _addStaffUser() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final selectedPermissions = <String, Set<String>>{};
    var isSubmitting = false;
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() {
              isSubmitting = true;
              error = null;
            });
            try {
              final response = await Supabase.instance.client.functions.invoke(
                'create-staff-user',
                body: {
                  'email': emailController.text.trim(),
                  'password': passwordController.text,
                  'permissions': [
                    for (final grant in selectedPermissions.entries)
                      for (final subcardKey in grant.value)
                        {
                          'section_key': grant.key,
                          'subcard_key': subcardKey,
                        },
                  ],
                },
              );
              final result = response.data;
              if (result is! Map || result['permissions_saved'] != true) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    error =
                        'The account may have been created, but the deployed '
                        'staff service did not confirm saving its section '
                        'permissions. The account can access Dashboard only '
                        'until an administrator verifies and assigns access.';
                  });
                }
                return;
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } on FunctionException catch (exception) {
              final details = exception.details;
              final message = details is Map ? details['error'] : null;
              if (dialogContext.mounted) {
                setDialogState(() {
                  error = message is String
                      ? message
                      : 'Could not create the staff account '
                          '(HTTP ${exception.status}).';
                });
              }
            } on AuthException {
              if (dialogContext.mounted) {
                setDialogState(() {
                  error = 'Your sign-in has expired. Sign in again and retry.';
                });
              }
            } on Exception {
              if (dialogContext.mounted) {
                setDialogState(() {
                  error =
                      'Could not reach the staff service. Confirm that the '
                      'database and create-staff-user function are deployed.';
                });
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isSubmitting = false);
              }
            }
          }

          return PopScope(
            canPop: !isSubmitting,
            child: AlertDialog(
            title: const Text('Add staff user'),
            scrollable: true,
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'New staff email',
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
                      validator: (value) => value == null || value.length < 12
                          ? 'Use at least 12 characters'
                          : null,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        'Dashboard is available to every staff member. '
                        'Assign the additional sections or individual cards '
                        'this account may access.',
                        style: TextStyle(color: _muted, height: 1.4),
                      ),
                    ),
                    _buildStaffPermissionSection(
                      0,
                      selectedPermissions,
                      setDialogState,
                      isSubmitting,
                      titlePrefix: 'Dashboard cards',
                    ),
                    for (var index = 1;
                        index < _StaffDashboardPageState._sections.length;
                        index++)
                      _buildStaffPermissionSection(
                        index,
                        selectedPermissions,
                        setDialogState,
                        isSubmitting,
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      _AuthErrorMessage(error!),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting ? null : submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create staff account'),
              ),
            ],
            ),
          );
        },
      ),
    );

    final createdEmail = emailController.text.trim();
    emailController.dispose();
    passwordController.dispose();
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Staff account created for $createdEmail.'),
        ),
      );
    }
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
    return ExpansionTile(
      key: PageStorageKey('staff-permission-${section.key}'),
      title: Text(titlePrefix ?? section.title),
      subtitle: Text(
        allSelected
            ? 'All cards'
            : selected.isEmpty
            ? 'No access assigned'
            : '${selected.length} card(s) selected',
      ),
      children: [
        CheckboxListTile(
          dense: true,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(child: _navigationPanel()),
      bottomNavigationBar: isWide ? null : _mobileNavigationBar(),
      appBar: AppBar(
        backgroundColor: _deepNavy,
        foregroundColor: Colors.white,
        title: const Text('Gelye Sherane · Management System'),
        actions: [
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
              tooltip: 'Add staff user',
              onPressed: _addStaffUser,
              icon: const Icon(Icons.person_add_alt_1),
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
          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
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
                        ? 'Administrator dashboard'
                        : 'Staff dashboard')
                  : section.title),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subcard == null
              ? section.description
              : 'Details for $subcard in ${section.title}.',
          style: TextStyle(color: _muted, height: 1.5),
        ),
        const SizedBox(height: 20),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5E2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEBD7AC)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: _ink),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Preview only: operational data tables and secure services '
                  'are not available in this Supabase project yet. No live '
                  'values or management actions are available here.',
                  style: TextStyle(color: _ink, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (subcard == null)
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

  Widget _sectionSubcardGrid(int sectionIndex) {
    if (sectionIndex == 0) return _dashboardLayout();
    final visibleSubcards = _visibleSubcards(sectionIndex);
    if (visibleSubcards.isEmpty) {
      return const Text('No cards in this section are assigned to this account.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final cardWidth =
            (constraints.maxWidth - (columnCount - 1) * 12) / columnCount;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final subcard in visibleSubcards)
              SizedBox(
                width: cardWidth,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _selectedSubcard = subcard),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(_sections[sectionIndex].icon, color: _gold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subcard,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Not connected',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
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
    final revenue = assignedCards.contains(_subcards.first.first)
        ? _subcards.first.first
        : null;
    final operationalCards = assignedCards.where(
      (card) => card != revenue,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (revenue != null)
          Card(
          color: _deepNavy,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _selectedSubcard = revenue),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Today Revenue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _statusPill('Not connected'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '— IQD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Live totals will appear when the authorized reporting '
                    'service is available.',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View details',
                        style: TextStyle(
                          color: Color(0xFF9FC7FF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: Color(0xFF9FC7FF),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
        if (revenue != null) const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth >= 560 ? 2 : 1;
            final cardWidth =
                (constraints.maxWidth - (columnCount - 1) * 12) / columnCount;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final title in operationalCards)
                  SizedBox(
                    width: cardWidth,
                    child: _dashboardTile(title),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1DD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFF9A5B00)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Operational data is not connected. No live alerts are shown.',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
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

  Widget _dashboardTile(String title) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedSubcard = title),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.circle_outlined, color: _navy),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Not connected',
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _subcardDetail(
    ({String key, IconData icon, String title, String description}) section,
    String subcard,
  ) {
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
          const Text(
            'This management area is specified, but its live data source, '
            'permissions, and operational actions are not implemented yet. '
            'No changes have been made.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
        ],
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
  final _newStaffEmailController = TextEditingController();
  final _newStaffPasswordController = TextEditingController();
  String? _error;
  String? _staffCreatedMessage;
  String? _mfaFactorId;
  String? _mfaEnrollmentSecret;
  bool? _isAdmin;
  bool _mfaPending = false;
  bool _isLoadingRole = false;
  bool _isSubmitting = false;
  bool _showCreateStaffForm = false;

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
    _newStaffEmailController.dispose();
    _newStaffPasswordController.dispose();
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
          _staffCreatedMessage = null;
          _showCreateStaffForm = false;
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

  Future<void> _createStaffAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
      _staffCreatedMessage = null;
    });

    final email = _newStaffEmailController.text.trim();
    try {
      await Supabase.instance.client.functions.invoke(
        'create-staff-user',
        body: {
          'email': email,
          'password': _newStaffPasswordController.text,
        },
      );
      if (!mounted) return;
      setState(() {
        _staffCreatedMessage = 'Staff account created for $email.';
        _newStaffEmailController.clear();
        _newStaffPasswordController.clear();
        _showCreateStaffForm = false;
      });
    } on FunctionException catch (exception) {
      if (mounted) {
        final details = exception.details;
        final message = details is Map ? details['error'] : null;
        setState(() {
          _error = message is String
              ? message
              : 'Could not create the staff account (HTTP ${exception.status}).';
        });
      }
    } on AuthException {
      if (mounted) {
        setState(() {
          _error = 'Your sign-in has expired. Sign in again and retry.';
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _error =
              'Could not reach the staff service. Confirm that the database '
              'and create-staff-user function are deployed.';
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
          OutlinedButton.icon(
            onPressed: _isSubmitting
                ? null
                : () => setState(() {
                    _showCreateStaffForm = !_showCreateStaffForm;
                    _error = null;
                    _staffCreatedMessage = null;
                  }),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(
              _showCreateStaffForm ? 'Cancel adding staff' : 'Add staff user',
            ),
          ),
          if (_showCreateStaffForm) ...[
            const SizedBox(height: 12),
            _createStaffForm(),
          ],
          if (_staffCreatedMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _staffCreatedMessage!,
              style: const TextStyle(color: Colors.green),
            ),
          ],
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

  Widget _createStaffForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _newStaffEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'New staff email',
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
            controller: _newStaffPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Initial password (12+ characters)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.password_outlined),
            ),
            validator: (value) => value == null || value.length < 12
                ? 'Use at least 12 characters'
                : null,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _createStaffAccount,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create staff account'),
            ),
          ),
        ],
      ),
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
