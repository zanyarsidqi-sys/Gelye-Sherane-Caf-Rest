import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/employee_permission_service.dart';
import 'gelye_professional_theme.dart';

class WebsiteSettingsPanel extends StatefulWidget {
  const WebsiteSettingsPanel({super.key});

  @override
  State<WebsiteSettingsPanel> createState() => _WebsiteSettingsPanelState();
}

class _WebsiteSettingsPanelState extends State<WebsiteSettingsPanel> {
  static const _bucket = 'cafe-website-assets';
  static const _maxImageBytes = 10 * 1024 * 1024;

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _openingHours = TextEditingController();

  bool _menu = true;
  bool _ordering = false;
  bool _reservations = false;
  bool _loading = true;
  bool _saving = false;
  bool _canEdit = false;
  bool _removeLogo = false;
  bool _removeHero = false;
  String _logoPath = '';
  String _heroPath = '';
  _PickedWebsiteImage? _logoSelection;
  _PickedWebsiteImage? _heroSelection;
  String? _error;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final permissions =
          await EmployeePermissionService().getSectionPermissions();
      final permission = permissions['websites_management'];
      if (permission?.canView != true) {
        throw StateError('Website management access denied');
      }
      final data = await _db
          .from('cafe_website_settings')
          .select(
            'title,description,phone,email,address,opening_hours,'
            'menu_enabled,ordering_requested,reservations_requested,'
            'website_logo_path,website_hero_path',
          )
          .eq('id', 1)
          .single();

      if (!mounted) return;
      setState(() {
        _canEdit = permission?.canEdit == true;
        _title.text = (data['title'] as String?) ?? '';
        _description.text = (data['description'] as String?) ?? '';
        _phone.text = (data['phone'] as String?) ?? '';
        _email.text = (data['email'] as String?) ?? '';
        _address.text = (data['address'] as String?) ?? '';
        _openingHours.text = (data['opening_hours'] as String?) ?? '';
        _menu = data['menu_enabled'] == true;
        _ordering = data['ordering_requested'] == true;
        _reservations = data['reservations_requested'] == true;
        _logoPath = (data['website_logo_path'] as String?) ?? '';
        _heroPath = (data['website_hero_path'] as String?) ?? '';
        _error = null;
      });
    } catch (error) {
      debugPrint('Website settings load failed: $error');
      if (mounted) {
        setState(() {
          _error =
              'Could not load Website Management. Check your access and that the website-assets migration is applied.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseImage({required bool isLogo}) async {
    if (!_canEdit || _saving) return;
    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
        withData: true,
      );
      if (selection == null || selection.files.isEmpty) return;

      final file = selection.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The selected file could not be read.');
      }
      if (bytes.length > _maxImageBytes) {
        throw StateError('Images must be 10 MB or smaller.');
      }
      final extension = (file.extension ?? '').toLowerCase();
      final contentType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => null,
      };
      if (contentType == null) {
        throw StateError('Choose a JPG, PNG, or WebP image.');
      }

      final picked = _PickedWebsiteImage(
        name: file.name,
        bytes: bytes,
        extension: extension,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logoSelection = picked;
          _removeLogo = false;
        } else {
          _heroSelection = picked;
          _removeHero = false;
        }
        _error = null;
      });
    } catch (error) {
      debugPrint('Website image selection failed: $error');
      final message = error is StateError
          ? error.message.toString()
          : 'Could not open that image. Try another file.';
      if (mounted) setState(() => _error = message);
    }
  }

  Future<String> _uploadImage(String slot, _PickedWebsiteImage image) async {
    final path =
        'site/$slot/${DateTime.now().microsecondsSinceEpoch}.${image.extension}';
    await _db.storage.from(_bucket).uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: image.contentType,
            upsert: false,
          ),
        );
    return path;
  }

  Future<void> _save() async {
    if (!_canEdit || _saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Website title is required.');
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid public contact email.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final oldLogoPath = _logoPath;
    final oldHeroPath = _heroPath;
    final newlyUploaded = <String>[];
    var nextLogoPath = _removeLogo ? '' : oldLogoPath;
    var nextHeroPath = _removeHero ? '' : oldHeroPath;

    try {
      if (_logoSelection != null) {
        nextLogoPath = await _uploadImage('logo', _logoSelection!);
        newlyUploaded.add(nextLogoPath);
      }
      if (_heroSelection != null) {
        nextHeroPath = await _uploadImage('hero', _heroSelection!);
        newlyUploaded.add(nextHeroPath);
      }
      await _db.from('cafe_website_settings').update({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'phone': _phone.text.trim(),
        'email': email,
        'address': _address.text.trim(),
        'opening_hours': _openingHours.text.trim(),
        'menu_enabled': _menu,
        'ordering_requested': _ordering,
        'reservations_requested': _reservations,
        'website_logo_path': nextLogoPath,
        'website_hero_path': nextHeroPath,
      }).eq('id', 1).select('id').single();
    } catch (error) {
      debugPrint('Website settings save failed: $error');
      if (newlyUploaded.isNotEmpty) {
        try {
          await _db.storage.from(_bucket).remove(newlyUploaded);
        } catch (cleanupError) {
          debugPrint('Temporary website image cleanup failed: $cleanupError');
        }
      }
      if (mounted) {
        setState(() {
          _error =
              'Save failed. Check your connection, website edit access, and the required storage migration.';
        });
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    final obsoletePaths = <String>[
      if (oldLogoPath.isNotEmpty && oldLogoPath != nextLogoPath) oldLogoPath,
      if (oldHeroPath.isNotEmpty && oldHeroPath != nextHeroPath) oldHeroPath,
    ];
    if (mounted) {
      setState(() {
        _logoPath = nextLogoPath;
        _heroPath = nextHeroPath;
        _logoSelection = null;
        _heroSelection = null;
        _removeLogo = false;
        _removeHero = false;
      });
    }

    var cleanupFailed = false;
    if (obsoletePaths.isNotEmpty) {
      try {
        await _db.storage.from(_bucket).remove(obsoletePaths);
      } catch (error) {
        cleanupFailed = true;
        debugPrint('Replaced website image cleanup failed: $error');
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleanupFailed
              ? 'Website saved. An old image could not be removed.'
              : 'Website changes saved.',
        ),
      ),
    );
  }

  String _publicImageUrl(String path) =>
      _db.storage.from(_bucket).getPublicUrl(path);

  Widget _imageCard({
    required BuildContext context,
    required String title,
    required String description,
    required String storagePath,
    required _PickedWebsiteImage? selection,
    required bool isRemoved,
    required bool isLogo,
  }) {
    final theme = Theme.of(context);
    final hasImage = selection != null || (storagePath.isNotEmpty && !isRemoved);
    final Widget image;
    if (selection != null) {
      image = Image.memory(selection.bytes, fit: BoxFit.cover);
    } else if (storagePath.isNotEmpty && !isRemoved) {
      image = Image.network(
        _publicImageUrl(storagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imagePlaceholder(theme, isLogo),
      );
    } else {
      image = _imagePlaceholder(theme, isLogo);
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: isLogo ? 1.8 : 2.35,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (hasImage)
                    Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        color: const Color(0xB8071D31),
                        child: Text(
                          selection == null ? 'Current website image' : 'Ready to save',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 4),
          Text(description, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _canEdit && !_saving
                    ? () => _chooseImage(isLogo: isLogo)
                    : null,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(selection == null ? 'Upload image' : 'Choose another'),
              ),
              if (hasImage)
                TextButton.icon(
                  onPressed: _canEdit && !_saving
                      ? () => setState(() {
                            if (isLogo) {
                              _logoSelection = null;
                              _removeLogo = true;
                            } else {
                              _heroSelection = null;
                              _removeHero = true;
                            }
                          })
                      : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                ),
            ],
          ),
          if (selection != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                selection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(ThemeData theme, bool isLogo) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLogo ? Icons.storefront_outlined : Icons.landscape_outlined,
                size: 34,
                color: GelyeProfessionalTheme.navy,
              ),
              const SizedBox(height: 6),
              Text(isLogo ? 'Add your logo' : 'Add a cover photo'),
            ],
          ),
        ),
      );

  Widget _sectionCard({
    required BuildContext context,
    required String title,
    required String description,
    required Widget child,
    IconData icon = Icons.tune_rounded,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: GelyeProfessionalTheme.navy),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
                    const SizedBox(height: 2),
                    Text(description, style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _livePreview(BuildContext context) {
    final theme = Theme.of(context);
    final Widget image;
    final Widget logoImage;
    if (_heroSelection != null) {
      image = Image.memory(_heroSelection!.bytes, fit: BoxFit.cover);
    } else if (_heroPath.isNotEmpty && !_removeHero) {
      image = Image.network(
        _publicImageUrl(_heroPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      image = const SizedBox.shrink();
    }
    if (_logoSelection != null) {
      logoImage = Image.memory(_logoSelection!.bytes, fit: BoxFit.cover);
    } else if (_logoPath.isNotEmpty && !_removeLogo) {
      logoImage = Image.network(
        _publicImageUrl(_logoPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_outlined),
      );
    } else {
      logoImage = const Icon(Icons.restaurant_outlined, color: Colors.white);
    }

    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [GelyeProfessionalTheme.navy, Color(0xFF35566E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xD9071D31), Color(0x16071D31)],
              ),
            ),
          ),
          PositionedDirectional(
            top: 12,
            start: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xB8071D31),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(width: 30, height: 30, child: logoImage),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 230),
                      child: Text(
                        _title.text.trim().isEmpty
                            ? 'Gelye Sherane Café & Restaurant'
                            : _title.text.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 54, 20, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'PUBLIC WEBSITE PREVIEW',
                      style: TextStyle(
                        color: GelyeProfessionalTheme.goldLight,
                        letterSpacing: 1.2,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _title.text.trim().isEmpty
                          ? 'Gelye Sherane Café & Restaurant'
                          : _title.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _description.text.trim().isEmpty
                          ? 'Your restaurant introduction will appear here.'
                          : _description.text.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE7EDF1),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactFields(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 2 : 1;
          final width =
              (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: TextField(
                  controller: _phone,
                  enabled: _canEdit,
                  maxLength: 50,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Public phone',
                    prefixIcon: Icon(Icons.call_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: TextField(
                  controller: _email,
                  enabled: _canEdit,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Public email',
                    prefixIcon: Icon(Icons.mail_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: TextField(
                  controller: _address,
                  enabled: _canEdit,
                  maxLength: 300,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Restaurant address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: TextField(
                  controller: _openingHours,
                  enabled: _canEdit,
                  maxLength: 300,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Opening hours',
                    prefixIcon: Icon(Icons.schedule_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          );
        },
      );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _openingHours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _title.text.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 36),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: GelyeProfessionalTheme.gold.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.web_outlined,
                color: GelyeProfessionalTheme.navy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your public website',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Edit the photos, contact details, and visitor options.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _livePreview(context),
        const SizedBox(height: 14),
        _sectionCard(
          context: context,
          title: 'Website photos',
          description:
              'Upload a brand logo and a cover photo. JPG, PNG, or WebP up to 10 MB each.',
          icon: Icons.photo_library_outlined,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gap = 12.0;
              final width = constraints.maxWidth >= 720
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: _imageCard(
                      context: context,
                      title: 'Restaurant logo',
                      description: 'Shown beside your restaurant name.',
                      storagePath: _logoPath,
                      selection: _logoSelection,
                      isRemoved: _removeLogo,
                      isLogo: true,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _imageCard(
                      context: context,
                      title: 'Homepage cover photo',
                      description: 'The large welcome image on your website.',
                      storagePath: _heroPath,
                      selection: _heroSelection,
                      isRemoved: _removeHero,
                      isLogo: false,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          context: context,
          title: 'Restaurant details',
          description: 'This name and introduction appear on the public page.',
          icon: Icons.storefront_outlined,
          child: Column(
            children: [
              TextField(
                controller: _title,
                enabled: _canEdit,
                maxLength: 100,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Restaurant name',
                  prefixIcon: Icon(Icons.restaurant_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                enabled: _canEdit,
                maxLength: 300,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Welcome introduction',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          context: context,
          title: 'Contact information',
          description:
              'Only these public contact fields are shown to website visitors.',
          icon: Icons.contact_phone_outlined,
          child: _contactFields(context),
        ),
        const SizedBox(height: 14),
        _sectionCard(
          context: context,
          title: 'Visitor options',
          description:
              'These controls show customer options; they do not bypass staff review or activate backend services.',
          icon: Icons.touch_app_outlined,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show menu'),
                subtitle: const Text('Let visitors browse the public menu.'),
                value: _menu,
                onChanged: _canEdit ? (value) => setState(() => _menu = value) : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Request online ordering'),
                subtitle: const Text('Orders remain subject to staff review.'),
                value: _ordering,
                onChanged: _canEdit
                    ? (value) => setState(() => _ordering = value)
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Request reservations'),
                subtitle: const Text('Guests provide their party size.'),
                value: _reservations,
                onChanged: _canEdit
                    ? (value) => setState(() => _reservations = value)
                    : null,
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _canEdit && !_saving ? _save : null,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving website…' : 'Save website changes'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: GelyeProfessionalTheme.gold,
            foregroundColor: GelyeProfessionalTheme.navy,
          ),
        ),
        if (!_canEdit) ...[
          const SizedBox(height: 8),
          const Text(
            'Read-only: Website Management edit permission is required.',
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _PickedWebsiteImage {
  const _PickedWebsiteImage({
    required this.name,
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String extension;
  final String contentType;
}
