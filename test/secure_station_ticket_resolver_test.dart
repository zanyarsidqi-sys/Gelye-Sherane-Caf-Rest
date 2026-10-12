import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/services/secure_station_ticket_resolver.dart';

void main() {
  final claim = <String, dynamic>{'ticket_id': 12, 'attempt': 1,
    'order_id': 99, 'station_key': 'kitchen'};
  final snapshot = <String, dynamic>{'ticket_id': 12, 'attempt': 1,
    'order_id': 99, 'station': 'kitchen',
    'items': [{'product': 'Tea', 'quantity': 2}]};

  test('valid immutable snapshot parses without a Supabase connection', () {
    final ticket = SecureStationTicketResolver.parseSnapshot(claim, snapshot);
    expect(ticket.orderId, 99);
    expect(ticket.items.single.quantity, 2);
  });
  test('different order identity is rejected', () {
    expect(() => SecureStationTicketResolver.parseSnapshot(claim,
      {...snapshot, 'order_id': 100}), throwsStateError);
  });
  test('invalid guest metadata is rejected without cast exceptions', () {
    expect(() => SecureStationTicketResolver.parseSnapshot(claim,
      {...snapshot, 'items': [{'product': 'Tea', 'quantity': 2,
        'guest_number': 'invalid'}]}), throwsStateError);
  });
  test('oversized immutable item list is rejected', () {
    expect(() => SecureStationTicketResolver.parseSnapshot(claim,
      {...snapshot, 'items': List.generate(501,
        (_) => {'product': 'Tea', 'quantity': 1})}), throwsStateError);
  });
  test('missing and invalid station identity are rejected', () {
    expect(() => SecureStationTicketResolver.parseSnapshot(
      {...claim, 'station_key': 'kitchen\nother'}, snapshot), throwsStateError);
  });

  test('unsupported immutable ticket kind is rejected before printing', () {
    expect(() => SecureStationTicketResolver.parseSnapshot(claim,
      {...snapshot, 'kind': 'REFUND'}), throwsStateError);
  });
  test('valid revision kind is accepted', () {
    final ticket = SecureStationTicketResolver.parseSnapshot(claim,
      {...snapshot, 'kind': 'CORRECTION'});
    expect(ticket.kind, 'CORRECTION');
  });
  test('total receipt size is bounded at snapshot parsing', () {
    final largeItems = List.generate(100, (index) => <String, dynamic>{
      'product': 'X' * 200, 'quantity': 1, 'note': 'Y' * 500,
    });
    expect(() => SecureStationTicketResolver.parseSnapshot(claim,
      {...snapshot, 'items': largeItems}), throwsStateError);
  });
}
