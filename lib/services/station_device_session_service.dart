import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Independent station device identity. Never place tokens in preferences/logs.
class StationDeviceSessionService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'gs_station_device_token_v1';
  Future<Map<String, dynamic>?> _request(String action, String token,
      {bool printerReady = false}) async {
    final result = await Supabase.instance.client.functions.invoke(
      'station-device-auth', body: {
        'action': action, 'token': token, 'printer_ready': printerReady,
      });
    if (result.data is! Map) return null;
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> signIn(String username, String password) async {
    final response = await Supabase.instance.client.functions.invoke(
      'station-device-auth', body: {
        'action': 'login', 'username': username, 'password': password,
      });
    if (response.data is! Map) throw StateError('Invalid station login response');
    final payload = Map<String, dynamic>.from(response.data as Map);
    final token = payload['token'];
    if (token is! String || token.length < 20 || payload['station'] is! String) {
      throw StateError('Invalid station login response');
    }
    await _storage.write(key: _key, value: token);
    return payload;
  }

  Future<Map<String, dynamic>?> restore() async {
    final token = await _storage.read(key: _key);
    if (token == null || token.isEmpty) return null;
    try {
      final response = await _request('heartbeat', token);
      if (response == null || response['station'] is! String) {
        await clearInvalidSession();
        return null;
      }
      return response;
    } catch (_) {
      // Network loss is not evidence of revocation: retain token for retry.
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> heartbeat({bool printerReady = false}) async {
    final token = await _storage.read(key: _key);
    if (token == null) return null;
    final response = await _request('heartbeat', token, printerReady: printerReady);
    if (response == null || response['station'] is! String) {
      await clearInvalidSession();
      return null;
    }
    return response;
  }

  /// Revoke on server before removing local credentials. If offline, keep the
  /// token so the user can retry revocation; never claim server logout worked.
  Future<void> logout() async {
    final token = await _storage.read(key: _key);
    if (token == null) return;
    final response = await _request('logout', token);
    if (response == null || response['revoked'] != true) {
      throw StateError('Server logout could not be confirmed');
    }
    await _storage.delete(key: _key);
  }


  /// Claims a station-scoped ticket. No printing occurs in this method.
  /// Never acknowledge "printed" before a physical printer driver confirms success.
  Future<Map<String, dynamic>?> claimPrintTicket() async {
    final token = await _storage.read(key: _key);
    if (token == null) throw StateError('Station device not signed in');
    final result = await _request('claim_print', token);
    if (result == null) throw StateError('Invalid print dispatch response');
    final ticket = result['ticket'];
    if (ticket == null) return null;
    if (ticket is! Map) throw StateError('Invalid print ticket');
    return Map<String, dynamic>.from(ticket);
  }

  /// Acknowledgment is explicitly driven by the printer worker/operator.
  /// A network failure must not cause blind resubmission of uncertain print jobs.
  Future<void> acknowledgePrintTicket({
    required int ticketId,
    required int attempt,
    required String result,
    String? error,
  }) async {
    if (!{'received', 'printed', 'failed'}.contains(result)) {
      throw ArgumentError.value(result, 'result', 'Unsupported print result');
    }
    final token = await _storage.read(key: _key);
    if (token == null) throw StateError('Station device not signed in');
    final response = await Supabase.instance.client.functions.invoke(
      'station-device-auth',
      body: {
        'action': 'ack_print', 'token': token,
        'ticket_id': ticketId, 'attempt': attempt,
        'result': result, if (error != null) 'error': error,
      },
    );
    if (response.data is! Map || response.data['acknowledged'] != true) {
      throw StateError('Print acknowledgment not confirmed');
    }
  }

  /// Revision print tickets have a separate queue and immutable event identity.
  Future<Map<String, dynamic>?> claimRevisionPrintTicket() async {
    final token=await deviceTokenForStationRequest();
    final result=await _request('claim_revision_print',token);
    if (result==null) throw StateError('Invalid revision claim response');
    final ticket=result['ticket'];
    if (ticket==null) return null;
    if (ticket is! Map) throw StateError('Invalid revision ticket');
    return Map<String,dynamic>.from(ticket);
  }

  Future<void> acknowledgeRevisionPrintTicket({required int ticketId,
    required int attempt,required String result,String? error}) async {
    if (!{'printed','failed','received'}.contains(result)) throw ArgumentError.value(result);
    final token=await deviceTokenForStationRequest();
    final response=await Supabase.instance.client.functions.invoke(
      'station-device-auth',body:{'action':'ack_revision_print','token':token,
      'ticket_id':ticketId,'attempt':attempt,'result':result,
      if(error!=null)'error':error});
    if (response.data is! Map || response.data['acknowledged']!=true) {
      throw StateError('Revision print acknowledgment not confirmed');
    }
  }

  /// Internal access for station-scoped API calls; never log or display tokens.
  Future<String> deviceTokenForStationRequest() async {
    final token = await _storage.read(key: _key);
    if (token == null || token.isEmpty) {
      throw StateError('Station device not signed in');
    }
    return token;
  }

  /// Only use after the server explicitly reports expired/revoked credentials.
  Future<void> clearInvalidSession() => _storage.delete(key: _key);
}
