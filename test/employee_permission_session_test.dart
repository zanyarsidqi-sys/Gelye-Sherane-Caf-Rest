import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gelye_cafe_rest/services/employee_permission_service.dart';
import 'package:gelye_cafe_rest/services/device_session_preference.dart';
import 'package:gelye_cafe_rest/services/saved_session_service.dart';

// Synthetic sessions and an in-memory HTTP transport: no backend is contacted.
Map<String, dynamic> user(String id) => {
  'id': id, 'aud': 'authenticated', 'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{}, 'created_at': '2026-01-01T00:00:00Z',
};
String session(String id, {String aal = 'aal2', String nonce = 'first'}) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value)))
      .replaceAll('=', '');
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  return jsonEncode({
    'access_token': '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
        '${part({'sub': id, 'exp': expiry, 'aal': aal, 'jti': nonce,
          'session_id': 'session-$nonce'})}.test',
    'refresh_token': 'test-refresh', 'token_type': 'bearer',
    'expires_in': 3600, 'expires_at': expiry, 'user': user(id),
  });
}
http.Response response(Object data) => http.Response(jsonEncode(data), 200,
    headers: {'content-type': 'application/json'});

void main() {
  late SupabaseClient client;
  late Future<http.Response> Function(http.Request) handle;
  late List<http.Request> requests;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    requests = [];
    handle = (_) async => response({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-public-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final result = await handle(request);
        return http.Response(result.body, result.statusCode,
            headers: result.headers, request: request);
      }),
    );
    client = Supabase.instance.client;
  });
  setUp(() async {
    await client.auth.signOut(scope: SignOutScope.local);
    await DeviceSessionPreference.clear();
    requests = [];
    handle = (request) async {
      if (request.url.path.endsWith('/user')) return response(user('employee-a'));
      if (request.url.path.endsWith('/employee_profiles')) {
        return response([{'user_id': 'employee-a', 'is_active': true}]);
      }
      if (request.url.path.endsWith('/employee_section_permissions')) {
        return response([{'section_key': 'dashboard', 'can_view': true,
          'can_create': false, 'can_edit': false, 'can_delete': false}]);
      }
      return response({});
    };
    await client.auth.recoverSession(session('employee-a'));
    final active = client.auth.currentSession;
    if (active == null) throw StateError('Synthetic session was not restored');
    await DeviceSessionPreference.save(active, 0);
  });
  tearDown(() async {
    await client.auth.signOut(scope: SignOutScope.local);
    await DeviceSessionPreference.clear();
  });
  tearDownAll(() async => await client.dispose());

  test('unchanged AAL2 session receives permitted sections', () async {
    expect(await EmployeePermissionService(client: client).getAllowedSections(),
        {'dashboard'});
    expect(requests.every((r) => r.url.queryParameters['user_id'] == 'eq.employee-a'), isTrue);
  });
  test('AAL1 cannot query employee data', () async {
    await client.auth.recoverSession(session('employee-a', aal: 'aal1'));
    await expectLater(EmployeePermissionService(client: client).getActiveEmployee(),
        throwsStateError);
    expect(requests, isEmpty);
  });
  test('profile belonging to another employee cannot authorize', () async {
    handle = (_) async => response([{'user_id': 'employee-b', 'is_active': true}]);
    expect(await EmployeePermissionService(client: client).getActiveEmployee(), isNull);
  });
  test('inactive employee cannot authorize', () async {
    handle = (_) async => response([{'user_id': 'employee-a', 'is_active': false}]);
    await expectLater(EmployeePermissionService(client: client).getAllowedSections(),
        throwsStateError);
  });
  for (final transition in ['other employee', 'same employee new token', 'MFA lost', 'sign out']) {
    test('pending permissions rejected after $transition', () async {
      final reached = Completer<void>();
      final delayed = Completer<http.Response>();
      final normal = handle;
      handle = (request) {
        if (request.url.path.endsWith('/employee_section_permissions')) {
          reached.complete(); return delayed.future;
        }
        return normal(request);
      };
      final pending = EmployeePermissionService(client: client).getAllowedSections();
      final assertion = expectLater(pending, throwsStateError);
      await reached.future;
      if (transition == 'sign out') {
        await client.auth.signOut(scope: SignOutScope.local);
      } else {
        await client.auth.recoverSession(session(
          transition == 'other employee' ? 'employee-b' : 'employee-a',
          aal: transition == 'MFA lost' ? 'aal1' : 'aal2', nonce: 'changed'));
      }
      delayed.complete(response([{'section_key': 'dashboard', 'can_view': true}]));
      await assertion;
    });
  }
  test('unresponsive profile request times out', () async {
    final delayed = Completer<http.Response>();
    handle = (_) => delayed.future;
    await expectLater(EmployeePermissionService(client: client,
        requestTimeout: const Duration(milliseconds: 20)).getActiveEmployee(),
        throwsA(isA<TimeoutException>()));
    delayed.complete(response([]));
  });
  test('saved session restores when identity and permissions match', () async {
    final result = await SavedSessionService(client: client).restoreSession();
    expect(result.authorized, isTrue);
    expect(result.allowedSections, {'dashboard'});
  });
  test('saved session denies a different server user', () async {
    handle = (_) async => response(user('employee-b'));
    expect((await SavedSessionService(client: client).restoreSession()).authorized, isFalse);
    expect(requests.length, 1);
  });
  test('saved session timeout ends startup without authorizing', () async {
    final delayed = Completer<http.Response>();
    handle = (_) => delayed.future;
    final result = await SavedSessionService(client: client,
        requestTimeout: const Duration(milliseconds: 20)).restoreSession();
    expect(result.authorized, isFalse);
    delayed.complete(response(user('employee-a')));
  });
}
