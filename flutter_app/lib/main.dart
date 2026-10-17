import 'cafe_language.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cafe_guest_page.dart';
import 'staff_dashboard_page.dart';

const _navy = Color(0xFF09243A);
const _deepNavy = Color(0xFF061A2B);
const _gold = Color(0xFFD6AA57);
const _ink = Color(0xFF182B3A);
const _muted = Color(0xFF677582);

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
);
const _supabaseExpectedProjectRef = String.fromEnvironment(
  'SUPABASE_EXPECTED_PROJECT_REF',
);

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
      _supabasePublishableKey.startsWith('sb_publishable_');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_hasValidSupabaseConfiguration) {
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );
  }
  await cafeLanguage.load();
  runApp(const CafeApp());
}

class CafeApp extends StatelessWidget {
  const CafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final qrToken = Uri.base.queryParameters['table'];
    return ListenableBuilder(listenable:cafeLanguage,builder:(context,_) => CafeLanguageScope(controller:cafeLanguage,child:MaterialApp(
      title: 'Gelye Sherane Management System',
      locale: Locale(cafeLanguage.language.code),
      supportedLocales: const [Locale('en'),Locale('ar'),Locale('ku')],
      localizationsDelegates: const [BadiniMaterialDelegate(), BadiniCupertinoDelegate(), ...GlobalMaterialLocalizations.delegates],
      debugShowCheckedModeBanner: false,
      builder: (context,child) => Directionality(
        textDirection:cafeLanguage.language.isRtl?TextDirection.rtl:TextDirection.ltr,
        child:const bool.fromEnvironment('CAFE_STAGING')
          ? Banner(message:'STAGING',location:BannerLocation.topEnd,child:child!)
          : child!),

      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2463EB),
          surface: Colors.white,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: const Color(0xFF18283F),
          displayColor: const Color(0xFF18283F),
        ),
      ),
      home: qrToken == null
          ? const CafeLandingPage()
          : CafeGuestPage(
              qrToken: qrToken,
              supabaseConfigured: _hasValidSupabaseConfiguration,
            ),
    )));
  }
}

class CafeLandingPage extends StatefulWidget {
  const CafeLandingPage({super.key});

  @override
  State<CafeLandingPage> createState() => _CafeLandingPageState();
}

class _CafeLandingPageState extends State<CafeLandingPage> {
  final _menuKey = GlobalKey();
  final _aboutKey = GlobalKey();
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
              content: CafeText(
                'Thanks, $name. This preview does not send booking requests yet.',
              ),
            ),
          );
        },
      ),
    );
  }

  void _openStaffPreview() {
    showDialog<void>(
      context: context,
      builder: (context) => StaffSignInDialog(
        supabaseConfigured: _hasValidSupabaseConfiguration,
        supabaseConfigurationProvided: _hasSupabaseConfiguration,
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
                onAbout: () => _scrollTo(_aboutKey),
                onBook: _openReservation,
                onStaff: _openStaffPreview,
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
                  if (isWide) ...[
                    const _BrandMark(),
                    const Spacer(),
                  ] else
                    const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: _BrandMark())),
                  const CafeLanguageButton(),
                  if (isWide) ...[
                    _HeaderLink(label: 'Home', onPressed: () {}),
                    _HeaderLink(label: 'Menu', onPressed: onMenu),
                    _HeaderLink(label: 'Our café', onPressed: onAbout),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: onStaff,
                      icon: const Icon(Icons.lock_outline, size: 17),
                      label: const CafeText('Staff portal'),
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
                      child: const CafeText('Book a table'),
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
                  child: const CafeText('Book a table'),
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
          child: const CafeText(
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
            CafeText(
              'Gelye Sherane',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            CafeText(
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
                          CafeText(
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
                          CafeText(
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
                                label: const CafeText('Book a table'),
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
                                label: const CafeText('Explore menu'),
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
        const CafeText(
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
                          const CafeText(
                            'Make time for a good meal.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 9),
                          CafeText(
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
                      label: const CafeText('Plan a visit'),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final copyright = CafeText(
                  '© ${DateTime.now().year} Gelye Sherane Café & Restaurant\nv1.0.7.8',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                  textAlign: constraints.maxWidth >= 560
                      ? TextAlign.end
                      : TextAlign.start,
                );
                if (constraints.maxWidth >= 560) {
                  return Row(
                    children: [
                      const Expanded(child: _BrandMark()),
                      copyright,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: 14),
                    copyright,
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
      title: const CafeText('Plan your visit'),
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
                  child: CafeText(
                    'Share your details and our team can help with your plans.',
                    style: TextStyle(color: _muted, height: 1.4),
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    label: CafeText('Your name'),
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
                    label: CafeText('Phone number'),
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
                        label: CafeText(
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
                          child: CafeText('${index + 1} guests'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const CafeText(
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
          child: const CafeText('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const CafeText('Send request')),
      ],
    );
  }
}
