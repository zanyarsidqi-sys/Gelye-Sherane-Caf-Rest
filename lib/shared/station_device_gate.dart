import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/device_session_preference.dart';
import '../services/station_device_session_service.dart';
import 'station_pos_login_screen.dart';
import '../services/secure_station_ticket_resolver.dart';

/// Standalone station device mode; no employee account is created.
class StationDeviceGate extends StatefulWidget {
  /// Provide a real configured printer driver. Without one printing stays off.
  const StationDeviceGate({
    super.key,
    required this.authorizedEmployeeUserId,
    required this.authorizedEmployeeSessionId,
    this.printerDriver,
  });
  final String authorizedEmployeeUserId;
  final String authorizedEmployeeSessionId;
  final StationPrinterDriver? printerDriver;
  @override State<StationDeviceGate> createState() => _StationDeviceGateState();
}
class _StationDeviceGateState extends State<StationDeviceGate> {
  final _session = StationDeviceSessionService();
  StreamSubscription<AuthState>? _employeeAuthSubscription;
  StationPrintLifecycle? _printLifecycle;
  bool _printerStarting = false;
  bool _authorizationLost = false;
  String? _printerStatus;
  void _stopPrinter() { _printLifecycle?.stop(); _printLifecycle=null; }
  Future<void> _syncPrinter() async {
    if (!mounted || _printerStarting) return;
    if (!_connected || !_orders || _station == null || widget.printerDriver == null) {
      _stopPrinter(); return;
    }
    if (_printLifecycle?.running == true) return;
    _printerStarting=true;
    try {
      final lifecycle=StationPrintLifecycle(_session,widget.printerDriver!);
      await lifecycle.start(onError:(error) {
        if (mounted) setState(() => _printerStatus = 'Printer requires attention: $error');
      });
      if (!mounted || !_connected || !_orders) { lifecycle.stop(); return; }
      _printLifecycle=lifecycle;
      setState(() => _printerStatus='Print workers active; printer confirmation required');
    } catch (e) {
      _stopPrinter();
      if (mounted) setState(() => _printerStatus='Printer unavailable: $e');
    } finally { _printerStarting=false; }
  }
  Timer? _timer;
  String? _station;
  bool _orders = false, _bills = false, _checking = true, _connected = false, _busy = false;
  String? _error;
  @override void initState() {
    super.initState();
    final auth = Supabase.instance.client.auth;
    if (!_employeeSessionIsCurrent(auth.currentSession)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_lockAfterEmployeeAuthorizationLost());
      });
      return;
    }
    _employeeAuthSubscription = auth.onAuthStateChange.listen((state) {
      if (!_employeeSessionIsCurrent(state.session)) {
        unawaited(_lockAfterEmployeeAuthorizationLost());
      }
    });
    _restore();
  }

  @override
  void dispose() {
    _stopPrinter();
    _timer?.cancel();
    _employeeAuthSubscription?.cancel();
    super.dispose();
  }

  bool _employeeSessionIsCurrent(Session? session) {
    final auth = Supabase.instance.client.auth;
    return session != null &&
        session.user.id == widget.authorizedEmployeeUserId &&
        auth.currentUser?.id == widget.authorizedEmployeeUserId &&
        DeviceSessionPreference.sessionId(session) ==
            widget.authorizedEmployeeSessionId &&
        auth.mfa.getAuthenticatorAssuranceLevel().currentLevel ==
            AuthenticatorAssuranceLevels.aal2;
  }

  Future<void> _lockAfterEmployeeAuthorizationLost() async {
    if (_authorizationLost) return;
    _authorizationLost = true;
    _stopPrinter();
    _timer?.cancel();
    _timer = null;
    try {
      // The server permits logout solely to revoke this exact station token.
      await _session.logout();
    } catch (_) {
      try {
        await _session.clearInvalidSession();
      } catch (_) {
        // The server still rejects the token because it is bound to the old
        // employee session; local storage cleanup is best effort.
      }
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
  }

  Future<void> _restore() async {
    try { final data = await _session.restore(); if (!mounted) return;
      if (data != null) _apply(data);
    } catch (error) {
      if (error is StationEmployeeAuthorizationException) {
        await _lockAfterEmployeeAuthorizationLost();
      } else if (mounted) {
        setState(() => _connected = false);
      }
    }
    finally { if (mounted) setState(() => _checking = false); }
  }
  void _apply(Map<String,dynamic> data) {
    setState(() { _station = data['station']?.toString();
      _orders = data['order_print'] == true; _bills = data['bill_print'] == true;
      _connected = true; });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _heartbeat());
    unawaited(_syncPrinter());
  }
  Future<void> _heartbeat() async {
    try { final data = await _session.heartbeat(); if (!mounted) return;
      if (data == null) { _stopPrinter(); _timer?.cancel(); setState(() { _station=null; _connected=false; }); }
      else { setState(() { _connected=true; _orders=data['order_print']==true;
        _bills=data['bill_print']==true; }); await _syncPrinter(); }
    } catch (error) {
      _stopPrinter();
      if (error is StationEmployeeAuthorizationException) {
        await _lockAfterEmployeeAuthorizationLost();
      } else if (mounted) {
        setState(() => _connected = false);
      }
    }
  }
  Future<void> _logout() async {
    _stopPrinter();
    _timer?.cancel();
    setState(() { _busy = true; _error = null; });
    try {
      await _session.logout();
      if (mounted) setState(() { _station=null; _connected=false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Unable to revoke device session. Reconnect and try again.'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if (_station == null) return StationPosLoginScreen(onAuthenticated: (station, orders, bills) {
      _apply({'station':station,'order_print':orders,'bill_print':bills});
    });
    return Scaffold(appBar:AppBar(title:Text('Station POS · $_station'), actions:[
      IconButton(onPressed:_busy?null:_logout,tooltip:'Sign out',icon:const Icon(Icons.logout))
    ]),body:ListView(padding:const EdgeInsets.all(24),children:[
      ListTile(leading:Icon(_connected?Icons.cloud_done:Icons.cloud_off),
        title:Text(_connected?'Device online':'Connection unavailable'),
        subtitle:const Text('Status from server heartbeat; printer health is not verified')),
      ListTile(leading:const Icon(Icons.receipt_long),title:const Text('Order ticket printing'),
        subtitle:Text(_orders?'Authorized':'Not authorized')),
      ListTile(leading:const Icon(Icons.print),title:const Text('Bill printing'),
        subtitle:Text(_bills?'Authorized':'Not authorized')),
      if (_error != null) Text(_error!,style:const TextStyle(color:Colors.red)),
      Text(_printerStatus ?? (widget.printerDriver == null
        ? 'No physical printer driver configured; automatic printing disabled.'
        : 'Waiting for printer readiness and authorized station session.')),
      OutlinedButton(onPressed:_heartbeat,child:const Text('Check connection')),
    ]));
  }
}
