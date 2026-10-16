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
      repository.updatePosition(id: 'table-id', x: 0.5, y: 0.5),
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
