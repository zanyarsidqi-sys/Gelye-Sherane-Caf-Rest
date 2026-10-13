import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_language.dart';
import 'gelye_professional_theme.dart';

typedef PublicContactLoader = Future<Map<String, dynamic>?> Function();

/// Public entry page for customers and employees.
///
/// Customer actions route to the existing public request flows. Contact data
/// and image paths come only from their narrow, allowlisted public RPCs.
class PublicLandingPage extends StatefulWidget {
  const PublicLandingPage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onStaffLogin,
    required this.onStationPos,
    required this.onOpenMenu,
    required this.onReserveTable,
    required this.onOrderOnline,
    this.contactLoader,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onStaffLogin;
  final VoidCallback onStationPos;
  final VoidCallback onOpenMenu;
  final VoidCallback onReserveTable;
  final VoidCallback onOrderOnline;
  final PublicContactLoader? contactLoader;

  @override
  State<PublicLandingPage> createState() => _PublicLandingPageState();
}

class _PublicLandingPageState extends State<PublicLandingPage> {
  late Future<Map<String, dynamic>?> _contactFuture;

  @override
  void initState() {
    super.initState();
    _contactFuture = _loadContact();
  }

  Future<Map<String, dynamic>?> _loadContact() async {
    final loader = widget.contactLoader;
    if (loader != null) return loader();
    final response = await Supabase.instance.client.rpc(
      'gs_public_website_contact',
    );
    Map<String, dynamic>? data;
    if (response is Map) data = Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      data = Map<String, dynamic>.from(response.first as Map);
    }
    if (data == null) return null;

    // Keep public contact fields and public brand images on separate,
    // allowlisted RPCs. Never read the private website settings table publicly.
    try {
      final brandingResponse = await Supabase.instance.client.rpc(
        'gs_public_website_branding',
      );
      Map<String, dynamic>? branding;
      if (brandingResponse is Map) {
        branding = Map<String, dynamic>.from(brandingResponse);
      } else if (brandingResponse is List &&
          brandingResponse.isNotEmpty &&
          brandingResponse.first is Map) {
        branding = Map<String, dynamic>.from(brandingResponse.first as Map);
      }
      if (branding != null) {
        final storage =
            Supabase.instance.client.storage.from('cafe-website-assets');
        final logoPath = _read(branding, 'logo_path');
        final heroPath = _read(branding, 'hero_path');
        if (logoPath.isNotEmpty) {
          data['logo_image_url'] = storage.getPublicUrl(logoPath);
        }
        if (heroPath.isNotEmpty) {
          data['hero_image_url'] = storage.getPublicUrl(heroPath);
        }
      }
    } catch (error) {
      debugPrint('Public website branding unavailable: $error');
    }
    return data;
  }

  String _label(BuildContext context, String english) =>
      AppLanguage.label(AppLanguage.of(context), english);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? const Color(0xFF071D31)
        : const Color(0xFFF6F2EA);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: FutureBuilder<Map<String, dynamic>?>(
          future: _contactFuture,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const <String, dynamic>{};
            final logoUrl = _read(data, 'logo_image_url');
            final title = _read(data, 'business_name');
            return Row(
              children: [
                if (logoUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      logoUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.restaurant, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Gelye Sherane Café & Rest' : title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh website content',
            onPressed: () => setState(() => _contactFuture = _loadContact()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [Color(0xFF071D31), Color(0xFF102C44)]
                : const [
                    Color(0xFFFBF7F0),
                    Color(0xFFF5F7FA),
                    Color(0xFFEFF3F5),
                  ],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            final horizontalPadding = constraints.maxWidth < 600 ? 18.0 : 32.0;
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: 8,
                bottom: 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _accessBar(context),
                      const SizedBox(height: 14),
                      _hero(context, isWide: isWide),
                      const SizedBox(height: 28),
                      Text(
                        _label(context, 'Choose how to visit'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _label(
                          context,
                          'Browse the menu, request a table, or order online.',
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _serviceCards(context),
                      const SizedBox(height: 32),
                      _contactSection(context),
                      const SizedBox(height: 28),
                      _websiteFooter(context),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _accessBar(BuildContext context) {
    final label = (String text) => _label(context, text);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: widget.onStaffLogin,
            icon: const Icon(Icons.lock_outline, size: 18),
            label: Text(label('Staff login')),
          ),
          OutlinedButton.icon(
            onPressed: widget.onStationPos,
            icon: const Icon(Icons.point_of_sale_outlined, size: 18),
            label: Text(label('Station POS')),
          ),
          IconButton.filledTonal(
            tooltip: label('Toggle theme'),
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, {required bool isWide}) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _contactFuture,
      builder: (context, snapshot) => _heroContent(
        context,
        isWide: isWide,
        website: snapshot.data ?? const <String, dynamic>{},
      ),
    );
  }

  Widget _heroContent(
    BuildContext context, {
    required bool isWide,
    required Map<String, dynamic> website,
  }) {
    final label = (String text) => _label(context, text);
    final headlineSize = isWide ? 42.0 : 33.0;
    final websiteName = _read(website, 'business_name');
    final websiteDescription = _read(website, 'description');
    final heroImageUrl = _read(website, 'hero_image_url');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GelyeProfessionalTheme.navy,
            GelyeProfessionalTheme.navySoft,
            Color(0xFF25445A),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26071D31),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (heroImageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                heroImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [Color(0xE5071D31), Color(0x48071D31)],
                ),
              ),
            ),
          ),
          Positioned(
            right: isWide ? 100 : -65,
            top: -95,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x22FFFFFF), width: 1.5),
                color: const Color(0x0DFFFFFF),
              ),
            ),
          ),
          Positioned(
            right: isWide ? 46 : -20,
            bottom: -32,
            child: const Icon(
              Icons.local_cafe_rounded,
              size: 170,
              color: Color(0x26F1CD7B),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isWide ? 42 : 26),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 700 : 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label('WELCOME TO GELYE SHERANE'),
                    style: const TextStyle(
                      color: GelyeProfessionalTheme.goldLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    websiteName.isEmpty
                        ? label('Gelye Sherane Café & Restaurant')
                        : websiteName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: headlineSize,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    websiteDescription.isEmpty
                        ? label(
                            'Browse the menu, reserve a table, or order online. Our team will confirm requests.',
                          )
                        : websiteDescription,
                    style: const TextStyle(
                      color: Color(0xFFE5ECF1),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const ValueKey('landing-menu-cta'),
                    onPressed: widget.onOpenMenu,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: Text(label('View menu')),
                    style: FilledButton.styleFrom(
                      backgroundColor: GelyeProfessionalTheme.gold,
                      foregroundColor: GelyeProfessionalTheme.navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceCards(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          final compact = contentWidth < 560;
          final columns = compact
              ? (contentWidth >= 330 ? 3 : 2)
              : contentWidth >= 850
                  ? 3
                  : 2;
          const gap = 12.0;
          final cardWidth =
              (contentWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              _ServiceCard(
                width: cardWidth,
                compact: compact,
                icon: Icons.menu_book_rounded,
                title: _label(context, 'Our menu'),
                description: _label(context, 'Explore dishes and prices.'),
                accent: const Color(0xFFB9802E),
                onTap: widget.onOpenMenu,
              ),
              _ServiceCard(
                width: cardWidth,
                compact: compact,
                icon: Icons.event_available_rounded,
                title: _label(context, 'Reservations'),
                description: _label(context, 'Choose a time and guest count.'),
                accent: const Color(0xFF2B7180),
                onTap: widget.onReserveTable,
              ),
              _ServiceCard(
                width: cardWidth,
                compact: compact,
                icon: Icons.shopping_bag_outlined,
                title: _label(context, 'Online ordering'),
                description: _label(context, 'Send an online order request.'),
                accent: const Color(0xFF9A5B46),
                onTap: widget.onOrderOnline,
              ),
            ],
          );
        },
      );

  Widget _contactSection(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: GelyeProfessionalTheme.gold.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  color: GelyeProfessionalTheme.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(context, 'Contact & hours'),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _label(context, 'Visit us or get in touch.'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<Map<String, dynamic>?>(
            future: _contactFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              if (snapshot.hasError) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        _label(
                          context,
                          'Contact details are temporarily unavailable.',
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => _contactFuture = _loadContact(),
                      ),
                      child: Text(_label(context, 'Try again')),
                    ),
                  ],
                );
              }
              final data = snapshot.data ?? const <String, dynamic>{};
              final businessName = _read(data, 'business_name');
              final description = _read(data, 'description');
              final fields = <(String, String, IconData)>[
                ('Phone', _read(data, 'phone'), Icons.call_outlined),
                ('Email', _read(data, 'email'), Icons.mail_outline),
                ('Address', _read(data, 'address'), Icons.location_on_outlined),
                (
                  'Opening hours',
                  _read(data, 'opening_hours'),
                  Icons.schedule_outlined,
                ),
              ].where((entry) => entry.$2.isNotEmpty).toList();

              if (businessName.isEmpty && description.isEmpty && fields.isEmpty) {
                return Text(
                  _label(
                    context,
                    'Contact details are not available yet.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (businessName.isNotEmpty)
                    Text(
                      businessName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  if (description.isNotEmpty) ...[
                    if (businessName.isNotEmpty) const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                  if (fields.isEmpty) ...[
                    if (businessName.isNotEmpty || description.isNotEmpty)
                      const SizedBox(height: 8),
                    Text(
                      _label(context, 'Contact details will appear here once published.'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (fields.isNotEmpty) ...[
                    if (businessName.isNotEmpty || description.isNotEmpty)
                      const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 650 ? 2 : 1;
                        final itemWidth =
                            (constraints.maxWidth - (columns - 1) * 12) /
                                columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: fields
                              .map(
                                (entry) => SizedBox(
                                  width: itemWidth,
                                  child: _ContactLine(
                                    label: _label(context, entry.$1),
                                    value: entry.$2,
                                    icon: entry.$3,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _websiteFooter(BuildContext context) => FutureBuilder<
      Map<String, dynamic>?>(
        future: _contactFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const <String, dynamic>{};
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 10),
                Text(
                  'All Rights Reserved for Gelye Sherane Café & Rest',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by Zanyar Sidqi',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      );

  String _read(Map<String, dynamic> data, String key) =>
      data[key]?.toString().trim() ?? '';
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.width,
    required this.compact,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });

  final double width;
  final bool compact;
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 138 : 150),
            padding: EdgeInsets.all(compact ? 12 : 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: compact
                      ? Alignment.center
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    width: compact ? 38 : 46,
                    height: compact ? 38 : 46,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: accent, size: compact ? 21 : 24),
                  ),
                ),
                SizedBox(height: compact ? 10 : 18),
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 13 : null,
                      ),
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                ),
                SizedBox(height: compact ? 3 : 6),
                Text(
                  description,
                  style: (compact
                          ? theme.textTheme.bodySmall
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                ),
                if (!compact) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: accent,
                      size: 20,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: GelyeProfessionalTheme.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
