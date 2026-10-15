import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_workspace_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late CafeWorkspaceRepository repository;

  setUp(() {
    client = SupabaseClient('https://example.supabase.co', 'test-anon-key');
    repository = CafeWorkspaceRepository(client);
  });

  tearDown(() async {
    await client.dispose();
  });

  test('create rejects malformed section keys before making a request', () {
    expect(
      () => repository.createRecord(
        sectionKey: 'bad section',
        subcardKey: 'live_tables',
        title: 'Dinner booking',
        details: '',
        amount: null,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('create rejects blank and oversized titles', () {
    for (final title in ['', '   ', 'x' * 161]) {
      expect(
        () => repository.createRecord(
          sectionKey: 'tables_orders',
          subcardKey: 'live_tables',
          title: title,
          details: '',
          amount: null,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('create rejects non-finite amounts', () {
    expect(
      () => repository.createRecord(
        sectionKey: 'tables_orders',
        subcardKey: 'live_tables',
        title: 'Dinner booking',
        details: '',
        amount: double.infinity,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('status updates reject unsupported values', () {
    expect(
      () => repository.updateStatus(recordId: 'record-id', status: 'paid'),
      throwsA(isA<FormatException>()),
    );
  });

  test('status updates and deletes require a signed-in user', () async {
    await expectLater(
      repository.updateStatus(recordId: 'record-id', status: 'completed'),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      repository.deleteRecord('record-id'),
      throwsA(isA<AuthException>()),
    );
  });
}
