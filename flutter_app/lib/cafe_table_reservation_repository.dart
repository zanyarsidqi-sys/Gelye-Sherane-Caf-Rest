import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class CafeTableReservation {
  const CafeTableReservation({
    required this.id,
    required this.requestId,
    required this.tableId,
    required this.customerName,
    required this.contact,
    required this.partySize,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.notes,
    required this.createdAt,
  });

  factory CafeTableReservation.fromJson(Map<String, dynamic> json) {
    return CafeTableReservation(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      tableId: json['table_id'] as String,
      customerName: json['customer_name'] as String,
      contact: json['contact'] as String,
      partySize: json['party_size'] as int,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      status: json['status'] as String,
      notes: json['notes'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String requestId;
  final String tableId;
  final String customerName;
  final String contact;
  final int partySize;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String notes;
  final DateTime createdAt;
}

class CafeTableReservationRepository {
  const CafeTableReservationRepository(this._client);

  final SupabaseClient _client;

  Future<List<CafeTableReservation>> fetchReservations() async {
    const pageSize = 500;
    final reservations = <CafeTableReservation>[];
    var offset = 0;

    while (true) {
      final rows = await _client
          .from('cafe_table_reservations')
          .select(
            'id,request_id,table_id,customer_name,contact,party_size,'
            'starts_at,ends_at,status,notes,created_at',
          )
          .order('starts_at')
          .order('id')
          .range(offset, offset + pageSize - 1);
      reservations.addAll(
        rows.map(
          (row) =>
              CafeTableReservation.fromJson(Map<String, dynamic>.from(row)),
        ),
      );
      if (rows.length < pageSize) return reservations;
      offset += pageSize;
    }
  }

  Future<CafeTableReservation> createReservation({
    required String requestId,
    required String tableId,
    required String customerName,
    required String contact,
    required int partySize,
    required DateTime startsAt,
    required DateTime endsAt,
    String notes = '',
  }) async {
    _validate(
      requestId: requestId,
      tableId: tableId,
      customerName: customerName,
      contact: contact,
      partySize: partySize,
      startsAt: startsAt,
      endsAt: endsAt,
      notes: notes,
    );
    _requireSignedIn();
    final row = await _client
        .rpc(
          'create_cafe_table_reservation',
          params: {
            'p_request_id': requestId,
            'p_table_id': tableId,
            'p_customer_name': customerName.trim(),
            'p_contact': contact.trim(),
            'p_party_size': partySize,
            'p_starts_at': startsAt.toUtc().toIso8601String(),
            'p_ends_at': endsAt.toUtc().toIso8601String(),
            'p_notes': notes.trim(),
          },
        )
        .single();
    return CafeTableReservation.fromJson(row);
  }

  Future<void> cancelReservation(String reservationId) async {
    _requireSignedIn();
    await _client.rpc(
      'cancel_cafe_table_reservation',
      params: {'p_reservation_id': reservationId},
    );
  }

  RealtimeChannel subscribe(void Function() onChange) {
    return _client
        .channel('cafe-table-reservations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cafe_table_reservations',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);

  String _requireSignedIn() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in again to manage table reservations.');
    }
    return userId;
  }

  static String newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  static void _validate({
    required String requestId,
    required String tableId,
    required String customerName,
    required String contact,
    required int partySize,
    required DateTime startsAt,
    required DateTime endsAt,
    required String notes,
  }) {
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidPattern.hasMatch(requestId) || !uuidPattern.hasMatch(tableId)) {
      throw const FormatException(
        'Reservation or table identifier is invalid.',
      );
    }
    if (customerName.trim().isEmpty || customerName.trim().runes.length > 120) {
      throw const FormatException(
        'Customer name must contain between 1 and 120 characters.',
      );
    }
    if (contact.trim().runes.length < 5 || contact.trim().runes.length > 80) {
      throw const FormatException(
        'Contact must contain between 5 and 80 characters.',
      );
    }
    if (partySize < 1 || partySize > 100) {
      throw const FormatException('Party size must be between 1 and 100.');
    }
    if (!startsAt.isBefore(endsAt) ||
        endsAt.difference(startsAt) > const Duration(hours: 12)) {
      throw const FormatException(
        'Reservation duration must be positive and no longer than 12 hours.',
      );
    }
    if (startsAt.isBefore(DateTime.now())) {
      throw const FormatException('Reservation time must be in the future.');
    }
    if (notes.runes.length > 1000) {
      throw const FormatException('Reservation notes are too long.');
    }
  }
}
