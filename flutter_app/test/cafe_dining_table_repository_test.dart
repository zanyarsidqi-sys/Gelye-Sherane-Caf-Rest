import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_dining_table_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late CafeDiningTableRepository repository;

  setUp(() {
    client = SupabaseClient('https://example.supabase.co', 'test-anon-key');
    repository = CafeDiningTableRepository(client);
  });

  tearDown(() async {
    await client.dispose();
  });

  test('creates require a valid name, area, and seat count', () async {
    for (final input in [
      (name: '', area: 'Main', seats: 4),
      (name: 'Table 1', area: ' ', seats: 4),
      (name: 'Table 1', area: 'Main', seats: 0),
      (name: 'Table 1', area: 'Main', seats: 101),
    ]) {
      await expectLater(
        repository.createTable(
          name: input.name,
          area: input.area,
          seats: input.seats,
          x: 0.5,
          y: 0.5,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('table coordinates must stay within the floor bounds', () async {
    for (final position in [(x: -0.1, y: 0.5), (x: 0.5, y: 1.1)]) {
      await expectLater(
        repository.createTable(
          name: 'Table 1',
          area: 'Main',
          seats: 4,
          x: position.x,
          y: position.y,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('tables expose the persisted normal pricing mode', () {
    final table = CafeDiningTable.fromJson({
      'id': 'table-id',
      'name': 'Table 1',
      'area': 'Main',
      'seats': 4,
      'status': 'available',
      'pricing_mode': 'normal',
      'position_x': 0.5,
      'position_y': 0.5,
    });

    expect(table.pricingMode, 'normal');
    expect(CafeDiningTableRepository.pricingModes, {'normal'});
  });

  test('map saves reject overlapping positions before making a request', () {
    final expectedUpdatedAt = DateTime.utc(2026, 10, 16);
    expect(
      repository.saveMapLayout(
        requestId: 'request-id',
        changes: [
          CafeDiningTableMapChange(
            id: 'table-a',
            expectedUpdatedAt: expectedUpdatedAt,
            expectedX: 0.3,
            expectedY: 0.4,
            x: 0.3,
            y: 0.4,
          ),
          CafeDiningTableMapChange(
            id: 'table-b',
            expectedUpdatedAt: expectedUpdatedAt,
            expectedX: 0.4,
            expectedY: 0.4,
            x: 0.35,
            y: 0.4,
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('map layout validation rejects duplicate table identifiers', () {
    final expectedUpdatedAt = DateTime.utc(2026, 10, 16);
    CafeDiningTableMapChange change(String id, double x) =>
        CafeDiningTableMapChange(
          id: id,
          expectedUpdatedAt: expectedUpdatedAt,
          expectedX: x,
          expectedY: 0.4,
          x: x,
          y: 0.4,
        );

    expect(
      repository.saveMapLayout(
        requestId: 'request-id',
        changes: [change('table-a', 0.2), change('table-a', 0.6)],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('table creation rejects unsupported pricing modes', () async {
    await expectLater(
      repository.createTable(
        name: 'Table 1',
        area: 'Main',
        seats: 4,
        x: 0.5,
        y: 0.5,
        pricingMode: 'unsupported',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('table mutations require a signed-in user', () async {
    await expectLater(
      repository.createTable(
        name: 'Table 1',
        area: 'Main',
        seats: 4,
        x: 0.5,
        y: 0.5,
      ),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      repository.updateStatus(id: 'table-id', status: 'unknown'),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      repository.deleteTable('table-id'),
      throwsA(isA<AuthException>()),
    );
  });
}
