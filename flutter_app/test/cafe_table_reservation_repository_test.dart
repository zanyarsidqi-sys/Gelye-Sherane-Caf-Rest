import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_table_reservation_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late SupabaseClient client;
  late CafeTableReservationRepository repository;

  setUp(() {
    client = SupabaseClient('https://example.supabase.co', 'test-anon-key');
    repository = CafeTableReservationRepository(client);
  });

  tearDown(() async {
    await client.dispose();
  });

  test('creates cryptographically random UUID v4 retry identifiers', () {
    final first = CafeTableReservationRepository.newRequestId();
    final second = CafeTableReservationRepository.newRequestId();
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(first, matches(uuidV4));
    expect(second, matches(uuidV4));
    expect(second, isNot(first));
  });

  test(
    'reservation input validation rejects malformed data before network use',
    () async {
      final startsAt = DateTime.now().add(const Duration(hours: 2));
      final endsAt = startsAt.add(const Duration(hours: 1));
      final requestId = CafeTableReservationRepository.newRequestId();
      const tableId = '00000000-0000-4000-8000-000000000001';

      for (final input in [
        (
          requestId: 'not-a-uuid',
          tableId: tableId,
          customerName: 'Guest',
          contact: '+964 750 123 4567',
          partySize: 2,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
        (
          requestId: requestId,
          tableId: tableId,
          customerName: ' ',
          contact: '+964 750 123 4567',
          partySize: 2,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
        (
          requestId: requestId,
          tableId: tableId,
          customerName: 'Guest',
          contact: '123',
          partySize: 2,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
        (
          requestId: requestId,
          tableId: tableId,
          customerName: 'Guest',
          contact: '+964 750 123 4567',
          partySize: 101,
          startsAt: startsAt,
          endsAt: endsAt,
        ),
        (
          requestId: requestId,
          tableId: tableId,
          customerName: 'Guest',
          contact: '+964 750 123 4567',
          partySize: 2,
          startsAt: endsAt,
          endsAt: startsAt,
        ),
        (
          requestId: requestId,
          tableId: tableId,
          customerName: 'Guest',
          contact: '+964 750 123 4567',
          partySize: 2,
          startsAt: startsAt,
          endsAt: startsAt.add(const Duration(hours: 13)),
        ),
        (
          requestId: requestId,
          tableId: tableId,
          customerName: 'Guest',
          contact: '+964 750 123 4567',
          partySize: 2,
          startsAt: DateTime.now().subtract(const Duration(minutes: 1)),
          endsAt: DateTime.now().add(const Duration(minutes: 30)),
        ),
      ]) {
        await expectLater(
          repository.createReservation(
            requestId: input.requestId,
            tableId: input.tableId,
            customerName: input.customerName,
            contact: input.contact,
            partySize: input.partySize,
            startsAt: input.startsAt,
            endsAt: input.endsAt,
          ),
          throwsA(isA<FormatException>()),
        );
      }
    },
  );

  test('valid reservation mutations require a signed-in user', () async {
    final startsAt = DateTime.now().add(const Duration(hours: 2));
    await expectLater(
      repository.createReservation(
        requestId: CafeTableReservationRepository.newRequestId(),
        tableId: '00000000-0000-4000-8000-000000000001',
        customerName: 'Guest',
        contact: '+964 750 123 4567',
        partySize: 2,
        startsAt: startsAt,
        endsAt: startsAt.add(const Duration(hours: 1)),
      ),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      repository.cancelReservation('reservation-id'),
      throwsA(isA<AuthException>()),
    );
  });
}
