import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_table_chair_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late CafeTableChairRepository repository;

  setUp(() {
    client = SupabaseClient('https://example.supabase.co', 'test-anon-key');
    repository = CafeTableChairRepository(client);
  });

  tearDown(() async {
    await client.dispose();
  });

  test('spare chair counts are bounded', () async {
    await expectLater(
      repository.reconcileSparePool(
        requestId: 'request-id',
        availableChairs: 10001,
        reason: 'Physical recount',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('chair movement requires a positive bounded quantity', () async {
    for (final quantity in [0, -1, 101]) {
      await expectLater(
        repository.moveChairs(
          requestId: 'request-id',
          operation: 'give',
          sourceTableId: null,
          destinationTableId: 'table-a',
          quantity: quantity,
          reason: 'Seat additional guests',
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('chair transfers require two distinct tables', () async {
    await expectLater(
      repository.moveChairs(
        requestId: 'request-id',
        operation: 'transfer',
        sourceTableId: 'table-a',
        destinationTableId: 'table-a',
        quantity: 1,
        reason: 'Move chairs',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('chair operations require a supported source and destination shape', () {
    expect(
      repository.moveChairs(
        requestId: 'request-id',
        operation: 'give',
        sourceTableId: 'table-a',
        destinationTableId: 'table-b',
        quantity: 1,
        reason: 'Move chairs',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      repository.moveChairs(
        requestId: 'request-id',
        operation: 'take',
        sourceTableId: 'table-a',
        destinationTableId: 'table-b',
        quantity: 1,
        reason: 'Return chairs',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('chair changes require a reason', () async {
    await expectLater(
      repository.setProtectedSeats(
        requestId: 'request-id',
        tableId: 'table-a',
        protectedSeats: 2,
        reason: ' ',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('chair operations require a signed-in user after validation', () async {
    await expectLater(
      repository.moveChairs(
        requestId: 'request-id',
        operation: 'give',
        sourceTableId: null,
        destinationTableId: 'table-a',
        quantity: 1,
        reason: 'Seat additional guests',
      ),
      throwsA(isA<AuthException>()),
    );
  });
}
