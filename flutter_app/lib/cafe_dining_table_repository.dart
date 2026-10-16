import 'package:supabase_flutter/supabase_flutter.dart';

class CafeDiningTable {
  const CafeDiningTable({
    required this.id,
    required this.name,
    required this.area,
    required this.seats,
    required this.status,
    required this.x,
    required this.y,
  });

  factory CafeDiningTable.fromJson(Map<String, dynamic> json) {
    return CafeDiningTable(
      id: json['id'] as String,
      name: json['name'] as String,
      area: json['area'] as String,
      seats: json['seats'] as int,
      status: json['status'] as String,
      x: (json['position_x'] as num).toDouble(),
      y: (json['position_y'] as num).toDouble(),
    );
  }

  final String id;
  final String name;
  final String area;
  final int seats;
  final String status;
  final double x;
  final double y;
}

class CafeDiningTableRepository {
  const CafeDiningTableRepository(this._client);

  static const statuses = {'available', 'occupied', 'reserved', 'cleaning'};
  static const _tableColumns =
      'id,name,area,seats,status,position_x,position_y';

  final SupabaseClient _client;

  Future<List<CafeDiningTable>> fetchTables() async {
    final rows = await _client
        .from('cafe_dining_tables')
        .select(_tableColumns)
        .order('area')
        .order('name');
    return rows
        .map((row) => CafeDiningTable.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<CafeDiningTable> createTable({
    required String name,
    required String area,
    required int seats,
    required double x,
    required double y,
  }) async {
    _validate(name: name, area: area, seats: seats, x: x, y: y);
    _requireSignedIn();
    final row = await _client
        .from('cafe_dining_tables')
        .insert({
          'name': name.trim(),
          'area': area.trim(),
          'seats': seats,
          'position_x': x,
          'position_y': y,
        })
        .select(_tableColumns)
        .single();
    return CafeDiningTable.fromJson(row);
  }

  Future<void> updateTable({
    required String id,
    required String name,
    required String area,
    required int seats,
  }) async {
    _validate(name: name, area: area, seats: seats, x: 0.5, y: 0.5);
    final userId = _requireSignedIn();
    await _client
        .from('cafe_dining_tables')
        .update({
          'name': name.trim(),
          'area': area.trim(),
          'seats': seats,
          'updated_by': userId,
        })
        .eq('id', id)
        .select('id')
        .single();
  }

  Future<void> updatePosition({
    required String id,
    required double x,
    required double y,
  }) async {
    _validate(name: 'table', area: 'area', seats: 1, x: x, y: y);
    final userId = _requireSignedIn();
    await _client
        .from('cafe_dining_tables')
        .update({'position_x': x, 'position_y': y, 'updated_by': userId})
        .eq('id', id)
        .select('id')
        .single();
  }

  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    if (!statuses.contains(status)) {
      throw const FormatException('Choose a supported table status.');
    }
    final userId = _requireSignedIn();
    await _client
        .from('cafe_dining_tables')
        .update({'status': status, 'updated_by': userId})
        .eq('id', id)
        .select('id')
        .single();
  }

  Future<void> deleteTable(String id) async {
    _requireSignedIn();
    await _client
        .from('cafe_dining_tables')
        .delete()
        .eq('id', id)
        .select('id')
        .single();
  }

  RealtimeChannel subscribe(void Function() onChange) {
    return _client
        .channel('cafe-dining-tables')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cafe_dining_tables',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);

  String _requireSignedIn() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in again to manage dining tables.');
    }
    return userId;
  }

  static void _validate({
    required String name,
    required String area,
    required int seats,
    required double x,
    required double y,
  }) {
    if (name.trim().isEmpty || name.trim().runes.length > 80) {
      throw const FormatException(
        'Table name must contain between 1 and 80 characters.',
      );
    }
    if (area.trim().isEmpty || area.trim().runes.length > 80) {
      throw const FormatException(
        'Area must contain between 1 and 80 characters.',
      );
    }
    if (seats < 1 || seats > 100) {
      throw const FormatException('Seat count must be between 1 and 100.');
    }
    if (!x.isFinite || x < 0 || x > 1 || !y.isFinite || y < 0 || y > 1) {
      throw const FormatException('Table position is outside the floor map.');
    }
  }
}
