import '../services/browser_push.dart';
import '../services/device_session_preference.dart';
import 'package:flutter/material.dart';
import '../shared/gelye_professional_theme.dart';
import '../shared/app_release_version.dart';
import '../shared/gelye_company_footer.dart';
import '../shared/release_update_notice.dart';
import '../shared/public_landing_page.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/pos_heartbeat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_gate.dart';
import '../shared/public_menu_screen.dart';
import '../shared/public_reservation_screen.dart';
import '../shared/public_online_order_screen.dart';
import '../shared/employee_device_presence_monitor.dart';
import '../shared/station_device_gate.dart';
import '../shared/customer_table_qr_menu_screen.dart';
import '../shared/customer_motel_room_qr_screen.dart';
import '../services/employee_permission_service.dart';
import '../services/saved_session_service.dart';
import '../screens/dashboard/dashboard_screen.dart';
import 'section_registry.dart';
import '../shared/app_language.dart';

class CafeApp extends StatefulWidget {
  const CafeApp({super.key});
  @override
  State<CafeApp> createState() => _CafeAppState();
}

class _CafeAppState extends State<CafeApp> {
  bool _checkingSavedSession = true;
  String _installedVersion = 'Loading…';
  Set<String> _restoredSections = <String>{};

  static const _languageKey = 'gelye_cafe_rest_language_v1';
  String _language = 'en';
  bool _dark = false;
  ThemeMode _selectedThemeMode = ThemeMode.system;

  int _appearanceChangeEpoch = 0;

  Future<void> _toggleTheme() async {
    final newValue = !_dark;
    // Apply the user's selection immediately; disk writes must not delay UI.
    final changeEpoch = ++_appearanceChangeEpoch;
    setState(() {
      _dark = newValue;
      _selectedThemeMode = newValue ? ThemeMode.dark : ThemeMode.light;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      // Do not let an older asynchronous toggle overwrite a newer selection.
      if (!mounted || changeEpoch != _appearanceChangeEpoch) return;
      await preferences.setBool('cafe_rest_dark_theme_v1', newValue);
      if (!mounted || changeEpoch != _appearanceChangeEpoch) return;
      await preferences.setString(
          'cafe_rest_theme_mode_v2', newValue ? 'dark' : 'light');
    } catch (error) {
      debugPrint('Could not save appearance preference: $error');
    }
  }

  Future<void> _loadAppearance() async {
    final loadEpoch = _appearanceChangeEpoch;
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedMode = preferences.getString('cafe_rest_theme_mode_v2');
      final legacyDark = preferences.getBool('cafe_rest_dark_theme_v1') ?? false;
      final mode = savedMode == 'dark'
          ? ThemeMode.dark
          : savedMode == 'light'
              ? ThemeMode.light
              : savedMode == 'system'
                  ? ThemeMode.system
                  : (legacyDark ? ThemeMode.dark : ThemeMode.light);
      // A late preference read cannot override a newer user toggle.
      if (mounted && loadEpoch == _appearanceChangeEpoch) {
        setState(() {
          _selectedThemeMode = mode;
          _dark = mode == ThemeMode.dark;
        });
      }
    } catch (error) {
      debugPrint('Could not load appearance preference: $error');
    }
  }

  final SavedSessionService _savedSessionService = SavedSessionService();
  @override
  void initState() {
    super.initState();
    _loadInstalledVersion();
    _loadAppearance();
    _loadLanguage();
    _restoreSavedSession();
  }

  void _loadInstalledVersion() {
    _installedVersion = AppReleaseVersion.label;
  }

  Future<void> _loadLanguage() async {
    final loadEpoch = _languageChangeEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_languageKey);
      // Do not replace a newer user selection with an older disk read.
      if (mounted && loadEpoch == _languageChangeEpoch &&
          const ['en', 'ar', 'ku_badini', 'ku_sorani'].contains(saved)) {
        setState(() => _language = saved!);
      }
    } catch (error) {
      debugPrint('Could not load language preference: $error');
    }
  }

  int _languageChangeEpoch = 0;

  Future<void> _changeLanguage(String code) async {
    if (!const ['en', 'ar', 'ku_badini', 'ku_sorani'].contains(code)) return;
    // A preference-write failure must not prevent changing the active UI.
    final changeEpoch = ++_languageChangeEpoch;
    if (mounted) setState(() => _language = code);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Skip obsolete writes when a newer language has already been selected.
      if (!mounted || changeEpoch != _languageChangeEpoch) return;
      await prefs.setString(_languageKey, code);
    } catch (error) {
      debugPrint('Could not save language preference: $error');
    }
  }

  Widget _globalLanguageSelector() => Material(
    elevation: 3,
    borderRadius: BorderRadius.circular(22),
    child: PopupMenuButton<String>(
      tooltip: AppLanguage.label(_language, 'Language'),
      onSelected: _changeLanguage,
      initialValue: _language,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'en', child: Text('English')),
        PopupMenuItem(value: 'ar', child: Text('العربية')),
        PopupMenuItem(value: 'ku_badini', child: Text('Kurdî — Badinî')),
        PopupMenuItem(value: 'ku_sorani', child: Text('کوردی — سۆرانی')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language, size: 19),
          const SizedBox(width: 4),
          Text(_language == 'en' ? 'EN' : _language == 'ar' ? 'AR' :
            _language == 'ku_badini' ? 'BAD' : 'SOR'),
          const Icon(Icons.arrow_drop_down, size: 18),
        ]),
      ),
    ),
  );

  Future<void> _restoreSavedSession() async {
    try {
      final authBefore = Supabase.instance.client.auth;
      final userBefore = authBefore.currentUser?.id;
      final sessionBefore = DeviceSessionPreference.sessionId(authBefore.currentSession);
      final result = await _savedSessionService.restoreSession();
      if (!mounted) return;
      // A stale asynchronous result must not unlock a signed-out session.
      final auth = Supabase.instance.client.auth;
      final stillAuthorized = result.authorized &&
          userBefore != null && sessionBefore != null &&
          auth.currentUser?.id == userBefore &&
          DeviceSessionPreference.sessionId(auth.currentSession) == sessionBefore &&
          auth.currentSession?.user.id == userBefore &&
          result.allowedSections.contains('dashboard') &&
          auth.currentSession != null &&
          auth.currentUser != null &&
          auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
              AuthenticatorAssuranceLevels.aal2;
      setState(() {
        _restoredSections =
            stillAuthorized
                ? Set<String>.unmodifiable(result.allowedSections)
                : <String>{};
        _checkingSavedSession = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _restoredSections = <String>{};
        _checkingSavedSession = false;
      });
    }
  }

  Widget _buildStaffAuthGate(BuildContext routeContext) {
    return AuthGate(
      onAuthorized: (allowedSections) {
        unawaited(
          _completeStaffAuthorization(routeContext, allowedSections),
        );
      },
    );
  }

  Future<void> _completeStaffAuthorization(
    BuildContext routeContext,
    Set<String> allowedSections,
  ) async {
    if (!routeContext.mounted) return;
    try {
      final client = Supabase.instance.client;
      final assurance = client.auth.mfa.getAuthenticatorAssuranceLevel();

      if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
        throw StateError('MFA verification required.');
      }

      // Bind this authorization attempt to the employee who began it.
      final employeeAtStart = client.auth.currentUser?.id;
      final sessionAtStart = client.auth.currentSession;
      if (employeeAtStart == null ||
          sessionAtStart?.user.id != employeeAtStart) {
        throw StateError('Employee session unavailable.');
      }
      final service = EmployeePermissionService();
      final profile = await service.getActiveEmployee();
      final verifiedSections = await service.getAllowedSections();

      if (profile == null ||
          profile['user_id'] != employeeAtStart ||
          profile['is_active'] != true ||
          verifiedSections.isEmpty ||
          client.auth.currentUser?.id != employeeAtStart ||
          client.auth.currentSession?.user.id != employeeAtStart ||
          client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
              AuthenticatorAssuranceLevels.aal2) {
        throw StateError('Employee access denied.');
      }

      final sections = verifiedSections.intersection(allowedSections);
      if (!sections.contains('dashboard')) {
        throw StateError('No authorized sections.');
      }
      if (!routeContext.mounted) return;

      Navigator.of(routeContext).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ManagementDashboard(
            allowedSections: sections,
            onToggleTheme: _toggleTheme,
            onAuthorizationLost: _clearRestoredEmployeeAccess,
            staffAuthGateBuilder: _buildStaffAuthGate,
            publicHomeBuilder: _buildPublicHome,
          ),
        ),
      );
    } catch (_) {
      if (!routeContext.mounted) return;
      ScaffoldMessenger.of(routeContext).showSnackBar(
        const SnackBar(
          content: Text(
            'Security verification failed. Management access remains locked.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openStaffEntrance(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: _buildStaffAuthGate),
    );
  }

  void _clearRestoredEmployeeAccess() {
    if (!mounted || _restoredSections.isEmpty) return;
    setState(() {
      _restoredSections = <String>{};
      _checkingSavedSession = false;
    });
  }

  Widget _buildPublicHome(BuildContext homeContext) {
    return PublicLandingPage(
      onToggleTheme: _toggleTheme,
      isDark: _dark,
      onStaffLogin: () => _openStaffEntrance(homeContext),
      onStationPos: () => Navigator.of(homeContext).push(
        MaterialPageRoute<void>(builder: (_) => const StationDeviceGate()),
      ),
      onOpenMenu: () => Navigator.of(homeContext).push(
        MaterialPageRoute<void>(builder: (_) => const PublicMenuScreen()),
      ),
      onReserveTable: () => Navigator.of(homeContext).push(
        MaterialPageRoute<void>(builder: (_) => const PublicReservationScreen()),
      ),
      onOrderOnline: () => Navigator.of(homeContext).push(
        MaterialPageRoute<void>(builder: (_) => const PublicOnlineOrderScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gelye Sherane Cafê & Rest',
      builder: (context, child) => AppLanguage(
        code: _language,
        child: Directionality(
          textDirection: AppLanguage.isRtl(_language) ? TextDirection.rtl : TextDirection.ltr,
          child: Column(children: [
        Expanded(child: Stack(children: [
        if (child != null)
          EmployeeDevicePresenceMonitor(
            child: ReleaseUpdateNotice(child: child),
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 6,
          right: 12,
          child: SafeArea(top: false, child: _globalLanguageSelector()),
        ),
      ])),
        GelyeCompanyFooter(version: _installedVersion),
      ]))),
      theme: GelyeProfessionalTheme.light,
      darkTheme: GelyeProfessionalTheme.dark,
      themeMode: _selectedThemeMode,
      home: Uri.base.queryParameters.containsKey('motel_room_token') && Uri.base.queryParameters['motel_room_token']!.isNotEmpty
          ? CustomerMotelRoomQrScreen(token: Uri.base.queryParameters['motel_room_token']!)
          : Uri.base.queryParameters.containsKey('token') && Uri.base.queryParameters['token']!.isNotEmpty
          ? CustomerTableQrMenuScreen(
              token: Uri.base.queryParameters['token']!,
              visitSessionToken: Uri.base.queryParameters['visit'])
          : _checkingSavedSession
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _restoredSections.isNotEmpty
              ? ManagementDashboard(
                  allowedSections: _restoredSections,
                  onToggleTheme: _toggleTheme,
                  onAuthorizationLost: _clearRestoredEmployeeAccess,
                  staffAuthGateBuilder: _buildStaffAuthGate,
                  publicHomeBuilder: _buildPublicHome,
                )
              : Builder(builder: _buildPublicHome),
    );
  }
}

class ManagementDashboard extends StatefulWidget {
  const ManagementDashboard({
    super.key,
    required this.allowedSections,
    required this.onToggleTheme,
    required this.onAuthorizationLost,
    required this.staffAuthGateBuilder,
    required this.publicHomeBuilder,
  });
  final Set<String> allowedSections;
  final VoidCallback onToggleTheme;
  final VoidCallback onAuthorizationLost;
  final WidgetBuilder staffAuthGateBuilder;
  final WidgetBuilder publicHomeBuilder;
  @override
  State<ManagementDashboard> createState() => _ManagementDashboardState();
}

class _ManagementDashboardState extends State<ManagementDashboard> with WidgetsBindingObserver {
  Timer? _posHeartbeatTimer;
  Timer? _accessReviewTimer;
  StreamSubscription<AuthState>? _authSubscription;
  bool _accessReviewBusy = false;
  bool _reviewRequestedWhileBusy = false;
  bool _logoutInProgress = false;
  bool _logoutRecoveryRequired = false;
  bool _redirectingForAuthorization = false;
  int _authorizationEpoch = 0;
  String? _authorizedUserId;
  // This route belongs to the employee who opened it; never transfer it to
  // another account after logout, token replacement or account switching.
  String? _openingEmployeeId;

  // Refresh authorization regularly; database RLS must independently enforce
  // revocation on every privileged request.
  void _startAccessMonitoring() {
    _accessReviewTimer?.cancel();
    _authSubscription?.cancel();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      _authorizationEpoch++;
      if (state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.userDeleted ||
          state.session == null ||
          state.session?.user.id != _openingEmployeeId ||
          (_authorizedUserId != null &&
              state.session?.user.id != _authorizedUserId)) {
        _lockManagement(showChecking: true);
        if (!_logoutInProgress && !_logoutRecoveryRequired) {
          _returnToStaffAuth();
        }
      } else {
        _checkAccess();
      }
    });
    _accessReviewTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && !_accessReviewBusy && !_logoutInProgress &&
          !_logoutRecoveryRequired &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _checkAccess();
      }
    });
  }

  void _lockManagement({bool showChecking = false}) {
    // Invalidate any in-flight permission response before it can unlock UI.
    _authorizationEpoch++;
    if (_logoutInProgress || _logoutRecoveryRequired) {
      _reviewRequestedWhileBusy = false;
    }
    _posHeartbeatTimer?.cancel();
    _favoritesGeneration++; // Reject preference reads started before this lock.
    if (!mounted) return;
    setState(() {
      _authorized = false;
      _sections = <String>{};
      _authorizedUserId = null;
      _favoriteSectionIds.clear();
      _loading = showChecking;
    });
  }

  void _returnToStaffAuth() {
    if (!mounted ||
        _redirectingForAuthorization ||
        _logoutInProgress ||
        _logoutRecoveryRequired) {
      return;
    }
    _redirectingForAuthorization = true;
    _authorizationEpoch++;
    _posHeartbeatTimer?.cancel();
    _posHeartbeatTimer = null;
    _favoritesGeneration++;
    final navigator = Navigator.of(context, rootNavigator: true);
    setState(() {
      _authorized = false;
      _sections = <String>{};
      _authorizedUserId = null;
      _favoriteSectionIds.clear();
      _loading = true;
    });
    widget.onAuthorizationLost();
    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: widget.publicHomeBuilder),
      (_) => false,
    );
    navigator.push<void>(
      MaterialPageRoute<void>(builder: widget.staffAuthGateBuilder),
    );
  }

  final PosHeartbeatService _posHeartbeat = PosHeartbeatService();
  bool _posHeartbeatBusy = false;

  Future<void> _sendPosHeartbeat() async {
    // Device telemetry must not run during a permission review, logout, or
    // after the authorized employee changes. The backend still enforces RLS.
    final client = Supabase.instance.client;
    if (_posHeartbeatBusy || !_authorized || _accessReviewBusy ||
        _logoutInProgress || _logoutRecoveryRequired ||
        !_sections.contains('tables') || _authorizedUserId == null ||
        client.auth.currentSession?.user.id != _authorizedUserId ||
        client.auth.currentUser?.id != _authorizedUserId ||
        client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
            AuthenticatorAssuranceLevels.aal2 ||
        kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    _posHeartbeatBusy = true;
    try {
      await _posHeartbeat.sendIfOptedIn();
    } catch (error) {
      // Heartbeat is best-effort telemetry. A timer callback must not leak an
      // unhandled Future error or interrupt employee workflows.
      debugPrint('POS heartbeat failed: $error');
    } finally {
      _posHeartbeatBusy = false;
    }
  }

  void _startPosHeartbeat() {
    _posHeartbeatTimer?.cancel();
    if (!_authorized || !_sections.contains('tables') ||
        kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    _sendPosHeartbeat();
    _posHeartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) => _sendPosHeartbeat());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockManagement(showChecking: true);
      _checkAccess();
    }
    else {
      _posHeartbeatTimer?.cancel();
      _posHeartbeatTimer = null;
      _lockManagement(showChecking: true);
      // No privileged dashboard content while backgrounded.
    }
  }

  @override
  void dispose() {
    _posHeartbeatTimer?.cancel();
    _accessReviewTimer?.cancel();
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _loading = true;
  bool _authorized = false;
  Set<String> _sections = {};
  String _sectionSearch = '';
  final List<String> _favoriteSectionIds = <String>[];
  int _favoritesGeneration = 0;

  String? get _favoritesStorageKey {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return userId == null ? null : 'cafe_rest_favorites_v1_$userId';
  }

  Future<void> _loadFavorites() async {
    final key = _favoritesStorageKey;
    if (key == null || !_authorized) return;
    final generation = _favoritesGeneration;
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getStringList(key) ?? <String>[];
      if (!mounted || !_authorized || generation != _favoritesGeneration ||
          key != _favoritesStorageKey) return;
      setState(() {
        _favoriteSectionIds
          ..clear()
          ..addAll(stored.where(_sections.contains).toSet());
      });
    } catch (error) {
      debugPrint('Could not load favorites: $error');
    }
  }

  // Serialize writes: an earlier slow save must never overwrite a later edit.
  Future<void> _favoriteWriteTail = Future<void>.value();

  Future<void> _saveFavorites() {
    final key = _favoritesStorageKey;
    if (key == null || !_authorized ||
        _authorizedUserId != Supabase.instance.client.auth.currentUser?.id) {
      return Future<void>.value();
    }
    final snapshot = List<String>.of(_favoriteSectionIds);
    final generation = _favoritesGeneration;
    final operation = _favoriteWriteTail.then((_) async {
      if (!mounted || !_authorized || generation != _favoritesGeneration ||
          key != _favoritesStorageKey ||
          _authorizedUserId != Supabase.instance.client.auth.currentUser?.id) return;
      try {
        final preferences = await SharedPreferences.getInstance();
        if (!mounted || !_authorized || generation != _favoritesGeneration ||
            key != _favoritesStorageKey ||
            _authorizedUserId != Supabase.instance.client.auth.currentUser?.id) return;
        await preferences.setStringList(key, snapshot);
      } catch (error) {
        debugPrint('Could not save favorites: $error');
      }
    });
    _favoriteWriteTail = operation;
    return operation;
  }

  void _toggleFavorite(String sectionId) {
    if (!_authorized || _authorizedUserId == null ||
        _authorizedUserId != Supabase.instance.client.auth.currentUser?.id ||
        !_sections.contains(sectionId)) return;
    // Invalidate any pending disk read before applying a local edit.
    _favoritesGeneration++;
    setState(() {
      if (_favoriteSectionIds.contains(sectionId)) {
        _favoriteSectionIds.remove(sectionId);
      } else {
        _favoriteSectionIds.add(sectionId);
      }
    });
    _saveFavorites();
  }

  Future<void> _resetFavorites() async {
    if (!_authorized || _authorizedUserId == null ||
        _authorizedUserId != Supabase.instance.client.auth.currentUser?.id) return;
    // A pending favorites load must not resurrect cleared favorites.
    _favoritesGeneration++;
    setState(() => _favoriteSectionIds.clear());
    await _saveFavorites();
    if (!mounted || !_authorized ||
        _authorizedUserId != Supabase.instance.client.auth.currentUser?.id) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your favorite workspaces were reset.')),
    );
  }

  void _moveFavorite(String sectionId, int direction) {
    if (!_authorized || _authorizedUserId == null ||
        _authorizedUserId != Supabase.instance.client.auth.currentUser?.id ||
        !_sections.contains(sectionId)) return;
    final index = _favoriteSectionIds.indexOf(sectionId);
    final next = index + direction;
    if (index < 0 || next < 0 || next >= _favoriteSectionIds.length) return;
    // Reject stale preference reads after a reorder.
    _favoritesGeneration++;
    setState(() {
      _favoriteSectionIds.removeAt(index);
      _favoriteSectionIds.insert(next, sectionId);
    });
    _saveFavorites();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openingEmployeeId = Supabase.instance.client.auth.currentUser?.id;
    _startAccessMonitoring();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    if (_logoutInProgress ||
        _logoutRecoveryRequired ||
        _redirectingForAuthorization ||
        !mounted) {
      return;
    }
    // Never authorize a management dashboard while the app is backgrounded.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _lockManagement(showChecking: true);
      return;
    }
    if (_accessReviewBusy) {
      // An auth/lifecycle-triggered overlap must invalidate the old result;
      // queue exactly one fresh verification after it finishes.
      _authorizationEpoch++;
      _reviewRequestedWhileBusy = true;
      setState(() {
        _authorized = false;
        _loading = true;
      });
      return;
    }
    _accessReviewBusy = true;
    _reviewRequestedWhileBusy = false;
    // Stop scheduled device telemetry until fresh authorization completes.
    _posHeartbeatTimer?.cancel();
    _posHeartbeatTimer = null;
    // A periodic review must not leave previously authorized UI interactive.
    setState(() {
      _authorized = false;
      _loading = true;
    });
    final reviewEpoch = _authorizationEpoch;
    final client = Supabase.instance.client;
    final sessionAtStart = client.auth.currentSession;
    final userAtStart = client.auth.currentUser?.id;
    try {
      if (sessionAtStart == null || userAtStart == null ||
          _openingEmployeeId == null || userAtStart != _openingEmployeeId ||
          sessionAtStart.user.id != _openingEmployeeId ||
          client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
              AuthenticatorAssuranceLevels.aal2) {
        _returnToStaffAuth();
        return;
      }
      final service = EmployeePermissionService();
      final profile = await service.getActiveEmployee();
      final permissions = await service.getAllowedSections();
      // Prevent an old asynchronous response from unlocking a new or signed-out session.
      final sessionNow = client.auth.currentSession;
      final valid = mounted && !_logoutInProgress &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          !_logoutRecoveryRequired && reviewEpoch == _authorizationEpoch &&
          sessionNow != null &&
          client.auth.currentUser?.id == userAtStart &&
          sessionNow.user.id == userAtStart &&
          userAtStart == _openingEmployeeId &&
          client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
              AuthenticatorAssuranceLevels.aal2 &&
          profile != null && profile['user_id'] == userAtStart &&
          profile['is_active'] == true &&
          permissions.contains('dashboard') &&
          widget.allowedSections.contains('dashboard');
      if (!valid) {
        _returnToStaffAuth();
        return;
      }
      setState(() {
        _authorized = true;
        _authorizedUserId = userAtStart;
        _sections = permissions.intersection(widget.allowedSections);
        _loading = false;
      });
      await _loadFavorites();
      // Loading preferences yields to the event loop: an auth event or
      // background transition may have invalidated the authorization.
      if (!mounted || !_authorized || !_sections.contains('dashboard') ||
          _logoutInProgress || _logoutRecoveryRequired ||
          reviewEpoch != _authorizationEpoch ||
          _authorizedUserId != client.auth.currentUser?.id ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      _startPosHeartbeat();
    } catch (_) {
      _returnToStaffAuth();
    } finally {
      _accessReviewBusy = false;
      if (mounted && !_logoutInProgress && !_logoutRecoveryRequired &&
          !_redirectingForAuthorization &&
          _reviewRequestedWhileBusy) {
        // Retry only on an actual concurrent request, not after a failed
        // permission check: otherwise a denied session can loop forever.
        _reviewRequestedWhileBusy = false;
        _checkAccess();
      }
    }
  }

  Future<void> _logout() async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;
    _logoutRecoveryRequired = true;
    // Lock immediately, even when network sign-out fails.
    _lockManagement();
    try {
      try { await disableBrowserPush(); } catch (_) {}
      await DeviceSessionPreference.clear();
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // A failed network logout may leave a valid local session. Never
      // rebuild CafeApp here: it could restore that session automatically.
      // Keep this dashboard locked until sign-out can be retried.
      _logoutInProgress = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sign-out could not finish. Access remains locked; retry sign-out.'),
        ));
      }
      return;
    }
    if (mounted) {
      widget.onAuthorizationLost();
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: widget.publicHomeBuilder),
        (_) => false,
      );
    }
  }

  bool _sectionNavigationBusy = false;

  Future<void> _openSection(CafeSection section) async {
    if (_sectionNavigationBusy) return;
    _sectionNavigationBusy = true;
    try {
    // A concurrent review must never allow navigation on cached permissions.
    // Hide the dashboard first, then require a fresh, completed review.
    if (_logoutInProgress || _logoutRecoveryRequired || !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    _lockManagement();
    if (_accessReviewBusy) {
      _reviewRequestedWhileBusy = true;
      return; // Never navigate on the result of an older review.
    }
    await _checkAccess();
    if (!mounted || !_authorized || _logoutInProgress ||
        _logoutRecoveryRequired || !_sections.contains(section.id) ||
        _authorizedUserId != Supabase.instance.client.auth.currentUser?.id ||
        Supabase.instance.client.auth.currentSession == null ||
        Supabase.instance.client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
            AuthenticatorAssuranceLevels.aal2 ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final authorizedUserId = _authorizedUserId!;
    final allowedSectionsSnapshot = Set<String>.unmodifiable(_sections);
    if (section.id == 'dashboard') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _ProtectedManagementSection(
            sectionId: 'dashboard',
            authorizedUserId: authorizedUserId,
            childBuilder: (context) => DashboardScreen(
            allowedSections: allowedSectionsSnapshot,
            onOpenSection: (sectionId) {
              final matches =
                  cafeSections.where((item) => item.id == sectionId);
              if (matches.isNotEmpty &&
                  allowedSectionsSnapshot.contains(sectionId)) {
                _openSection(matches.first);
              }
            },
          ),
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => _ProtectedManagementSection(
          sectionId: section.id,
          authorizedUserId: authorizedUserId,
          childBuilder: section.builder,
        ),
      ),
    );
    } finally {
      _sectionNavigationBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking your staff session…'),
            ],
          ),
        ),
      );
    }
    if (_logoutRecoveryRequired) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sign-out needs retry'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              const Text('This workspace is locked until sign-out finishes.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _logoutInProgress ? null : _logout,
                child: const Text('Retry sign-out'),
              ),
            ],
          ),
        ),
      );
    }
    if (!_authorized || _sections.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Returning to staff sign-in…'),
            ],
          ),
        ),
      );
    }

    final selected =
        cafeSections.where((item) => _sections.contains(item.id)).toList();
    final favorites = <CafeSection>[
      for (final id in _favoriteSectionIds)
        ...selected.where((section) => section.id == id),
    ];
    final filtered = selected
        .where((section) => section.title
            .toLowerCase()
            .contains(_sectionSearch.trim().toLowerCase()))
        .toList();
    return LayoutBuilder(builder: (context, bounds) {
      final wide = bounds.maxWidth >= 850;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gelye Sherane'),
          actions: [
            IconButton(
                tooltip: 'Refresh access',
                onPressed: _checkAccess,
                icon: const Icon(Icons.refresh)),
            IconButton(
                tooltip: 'Appearance',
                onPressed: widget.onToggleTheme,
                icon: const Icon(Icons.brightness_6)),
            IconButton(
                tooltip: 'Sign out',
                onPressed: _logout,
                icon: const Icon(Icons.logout)),
          ],
        ),
        drawer: wide
            ? null
            : Drawer(
                child: SafeArea(
                    child: ListView(children: [
                const ListTile(
                    title: Text('Management',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                for (final section in selected)
                  ListTile(
                      leading: const Icon(Icons.chevron_right),
                      title: Text(AppLanguage.label(AppLanguage.of(context), section.title)),
                      onTap: () {
                        Navigator.of(context).pop();
                        _openSection(section);
                      }),
              ]))),
        body: Row(children: [
          if (wide)
            SizedBox(
                width: 260,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        const ListTile(
                            title: Text('WORKSPACE',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        for (final section in selected)
                          ListTile(
                              dense: true,
                              leading: const Icon(Icons.grid_view_outlined),
                              title: Text(AppLanguage.label(AppLanguage.of(context), section.title)),
                              onTap: () => _openSection(section)),
                      ]),
                )),
          Expanded(
              child: RefreshIndicator(
                  onRefresh: _checkAccess,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLanguage.label(AppLanguage.of(context), 'Your workspace'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 6),
                            const Text('Gelye Sherane Cafê & Rest'),
                            const SizedBox(height: 16),
                            Wrap(spacing: 10, runSpacing: 10, children: [
                              Chip(
                                avatar: const Icon(Icons.verified_user_outlined,
                                    size: 18),
                                label: Text(
                                    '${selected.length} authorized sections'),
                              ),
                              Chip(
                                avatar:
                                    const Icon(Icons.star_outline, size: 18),
                                label: Text('${favorites.length} favorites'),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(AppLanguage.label(AppLanguage.of(context), 'Quick access'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final id in const [
                          'dashboard',
                          'tables',
                          'table_orders',
                          'motel_orders',
                          'kitchen',
                          'menu'
                        ])
                          if (selected.any((section) => section.id == id))
                            ActionChip(
                                avatar:
                                    const Icon(Icons.arrow_outward, size: 18),
                                label: Text(AppLanguage.label(AppLanguage.of(context), selected
                                    .firstWhere((section) => section.id == id)
                                    .title)),
                                onPressed: () => _openSection(
                                    selected.firstWhere(
                                        (section) => section.id == id))),
                      ]),
                      if (favorites.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Row(children: [
                          Expanded(
                              child: Text('My favorites',
                                  style:
                                      Theme.of(context).textTheme.titleLarge)),
                          TextButton.icon(
                            onPressed: _resetFavorites,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset'),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        for (final section in favorites)
                          ListTile(
                            leading:
                                const Icon(Icons.star, color: Colors.amber),
                            title: Text(AppLanguage.label(AppLanguage.of(context), section.title)),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'Move up',
                                onPressed: favorites.indexOf(section) == 0
                                    ? null
                                    : () => _moveFavorite(section.id, -1),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                              IconButton(
                                tooltip: 'Move down',
                                onPressed: favorites.indexOf(section) ==
                                        favorites.length - 1
                                    ? null
                                    : () => _moveFavorite(section.id, 1),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                            ]),
                            onTap: () => _openSection(section),
                          ),
                      ],
                      const SizedBox(height: 22),
                      Text(AppLanguage.label(AppLanguage.of(context), 'Find a workspace'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search authorized sections',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setState(() => _sectionSearch = value),
                      ),
                      const SizedBox(height: 14),
                      Text('Sections (${filtered.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No matching authorized sections.'),
                        ),
                      for (final section in filtered)
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.grid_view_rounded),
                          title: Text(AppLanguage.label(AppLanguage.of(context), section.title)),
                          trailing: IconButton(
                            tooltip: _favoriteSectionIds.contains(section.id)
                                ? 'Remove from favorites'
                                : 'Add to favorites',
                            icon: Icon(_favoriteSectionIds.contains(section.id)
                                ? Icons.star
                                : Icons.star_border),
                            onPressed: () => _toggleFavorite(section.id),
                          ),
                          onTap: () => _openSection(section),
                        ),
                    ],
                  ))),
        ]),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (index) {
                  if (index == 0) return;
                  final ids = [
                    '',
                    'dashboard',
                    'tables',
                    'table_orders',
                    'menu'
                  ];
                  final id = ids[index];
                  final match = selected.where((section) => section.id == id);
                  if (match.isNotEmpty) {
                    _openSection(match.first);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'This section is not available for your account.')));
                  }
                },
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined), label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
                  NavigationDestination(
                      icon: Icon(Icons.table_restaurant_outlined),
                      label: 'Tables'),
                  NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
                  NavigationDestination(
                      icon: Icon(Icons.restaurant_menu_outlined),
                      label: 'Menu'),
                ],
              ),
      );
    });
  }
}

// Each management route independently hides privileged widgets during checks.
// RLS remains the mandatory server-side authorization boundary.
class _ProtectedManagementSection extends StatefulWidget {
  const _ProtectedManagementSection({
    required this.sectionId,
    required this.authorizedUserId,
    required this.childBuilder,
  });
  final String sectionId;
  final String authorizedUserId;
  final WidgetBuilder childBuilder;

  @override
  State<_ProtectedManagementSection> createState() => _ProtectedManagementSectionState();
}

class _ProtectedManagementSectionState extends State<_ProtectedManagementSection>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<AuthState>? _subscription;
  bool _allowed = false;
  bool _verificationInFlight = false;
  bool _verificationQueued = false;
  bool _sessionTerminated = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      _lock();
      // A route opened for an employee never transfers to another session.
      if (state.event == AuthChangeEvent.signedOut ||
          state.event == AuthChangeEvent.userDeleted ||
          state.session == null ||
          state.session?.user.id != widget.authorizedUserId) {
        _sessionTerminated = true;
        return;
      }
      if (!_sessionTerminated && state.session != null &&
          state.session?.user.id == widget.authorizedUserId &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _verify();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      // A routine timer tick must not invalidate a permission request that is
      // already running. Auth/lifecycle events still queue a fresh review.
      if (!_verificationInFlight && !_sessionTerminated) _verify();
    });
    _verify();
  }

  @override
  void didUpdateWidget(covariant _ProtectedManagementSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorizedUserId != widget.authorizedUserId ||
        oldWidget.sectionId != widget.sectionId) {
      _lock();
      // Never transfer a terminated session to a new employee or section.
      _sessionTerminated = true;
    }
  }

  void _lock() {
    _generation++;
    if (mounted && _allowed) setState(() => _allowed = false);
  }

  Future<void> _verify() async {
    if (!mounted) return;
    _lock(); // Never show previously authorized content during a new review.
    if (_sessionTerminated ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    // Only one backend authorization read at a time. If an auth event arrives
    // during a read, invalidate that read and queue one fresh verification.
    if (_verificationInFlight) {
      _verificationQueued = true;
      return;
    }
    _verificationInFlight = true;
    final generation = ++_generation;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser?.id;
    try {
      if (client.auth.currentSession == null ||
          user != widget.authorizedUserId ||
          client.auth.currentSession?.user.id != widget.authorizedUserId) {
        // A protected route is permanently bound to its opening employee.
        _sessionTerminated = true;
        _lock();
        return;
      }
      if (client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
          AuthenticatorAssuranceLevels.aal2) {
        _lock();
        return;
      }
      final service = EmployeePermissionService();
      final profile = await service.getActiveEmployee();
      final permissions = await service.getAllowedSections();
      final valid = mounted && !_sessionTerminated && !_verificationQueued &&
          generation == _generation &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          client.auth.currentSession?.user.id == widget.authorizedUserId &&
          client.auth.currentUser?.id == widget.authorizedUserId &&
          client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
              AuthenticatorAssuranceLevels.aal2 &&
          profile != null && profile['user_id'] == widget.authorizedUserId &&
          profile['is_active'] == true &&
          permissions.contains('dashboard') &&
          permissions.contains(widget.sectionId);
      if (mounted && generation == _generation) {
        setState(() => _allowed = valid);
      }
    } catch (_) {
      if (mounted && generation == _generation) _lock();
    } finally {
      _verificationInFlight = false;
      if (mounted && _verificationQueued && !_sessionTerminated) {
        _verificationQueued = false;
        // A follow-up is required after overlapping auth/lifecycle events.
        // No automatic retry is scheduled for an ordinary access denial.
        _verify();
      }
    }
  }

  // Explicit recovery for transient permission/network errors. The route stays
  // bound to its original employee; sign-out or identity changes cannot retry.
  void _retryProtectedAccess() {
    if (_sessionTerminated || _verificationInFlight || !mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null || session.user.id != widget.authorizedUserId) {
      _sessionTerminated = true;
      _lock();
      return;
    }
    _verify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _lock();
    } else {
      _verify();
    }
  }

  @override
  void dispose() {
    _generation++;
    _verificationQueued = false;
    _timer?.cancel();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _allowed
      ? widget.childBuilder(context)
      : Scaffold(body: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(height: 12),
            Text(_sessionTerminated
                ? 'Employee session ended. Close this screen and sign in again.'
                : 'Checking employee access or access denied.'),
            const SizedBox(height: 12),
            if (!_sessionTerminated)
              TextButton(
                onPressed: _verificationInFlight ? null : _retryProtectedAccess,
                child: const Text('Recheck access'),
              ),
          ],
        )));
}


