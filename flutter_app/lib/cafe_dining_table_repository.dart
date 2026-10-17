import 'package:supabase_flutter/supabase_flutter.dart';

class CafeDiningTableMapChange {
  const CafeDiningTableMapChange({
    required this.id,
    required this.expectedUpdatedAt,
    required this.expectedX,
    required this.expectedY,
    required this.x,
    required this.y,
  });

  final String id;
  final DateTime expectedUpdatedAt;
  final double expectedX;
  final double expectedY;
  final double x;
  final double y;

  Map<String, Object> toJson() => {
    'id': id,
    'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
    'expected_position_x': expectedX,
    'expected_position_y': expectedY,
    'position_x': x,
    'position_y': y,
  };
}

class CafeDiningTable {
  const CafeDiningTable({
    required this.id,
    required this.name,
    required this.area,
    required this.seats,
    required this.status,
    required this.pricingMode,
    required this.x,
    required this.y,
    required this.updatedAt,
  });

  factory CafeDiningTable.fromJson(Map<String, dynamic> json) {
    return CafeDiningTable(
      id: json['id'] as String,
      name: json['name'] as String,
      area: json['area'] as String,
      seats: json['seats'] as int,
      status: json['status'] as String,
      pricingMode: json['pricing_mode'] as String,
      x: (json['position_x'] as num).toDouble(),
      y: (json['position_y'] as num).toDouble(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String name;
  final String area;
  final int seats;
  final String status;
  final String pricingMode;
  final double x;
  final double y;
  final DateTime? updatedAt;
}

class CafeDiningTableRepository {
  const CafeDiningTableRepository(this._client);

  static const statuses = {'available', 'occupied', 'reserved', 'cleaning'};
  static const pricingModes = {'normal', 'tourism', 'owner'};
  static const mapCanvasWidth = 900.0;
  static const mapCanvasHeight = 520.0;
  static const mapTableWidth = 128.0;
  static const mapTableHeight = 86.0;

  final SupabaseClient _client;

  Future<List<CafeDiningTable>> fetchTables() async {
    final rows = await _client.rpc('list_cafe_dining_tables');
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
    String pricingMode = 'normal',
  }) async {
    _validate(name: name, area: area, seats: seats, x: x, y: y);
    _validatePricingMode(pricingMode);
    _requireSignedIn();
    final row = await _client
        .rpc(
          'create_cafe_dining_table',
          params: {
            'table_name': name.trim(),
            'table_area': area.trim(),
            'table_seats': seats,
            'table_position_x': x,
            'table_position_y': y,
            'table_pricing_mode': pricingMode,
          },
        )
        .single();
    return CafeDiningTable.fromJson(row);
  }

  Future<void> updateTable({
    required String id,
    required String name,
    required String area,
    required int seats,
    required String pricingMode,
  }) async {
    _validate(name: name, area: area, seats: seats, x: 0.5, y: 0.5);
    _validatePricingMode(pricingMode);
    final userId = _requireSignedIn();
    await _client
        .from('cafe_dining_tables')
        .update({
          'name': name.trim(),
          'area': area.trim(),
          'seats': seats,
          'pricing_mode': pricingMode,
          'updated_by': userId,
        })
        .eq('id', id)
        .select('id')
        .single();
  }

  Future<void> saveMapLayout({
    required String requestId,
    required List<CafeDiningTableMapChange> changes,
  }) async {
    _validateMapLayout(changes);
    _requireSignedIn();
    final saved = await _client.rpc(
      'save_cafe_dining_table_map_layout',
      params: {
        'p_request_id': requestId,
        'p_changes': changes.map((change) => change.toJson()).toList(),
      },
    );
    if (saved is! List || saved.length != changes.length) {
      throw const FormatException(
        'The server did not confirm every table-map position.',
      );
    }
    final expectedIds = changes.map((change) => change.id).toSet();
    final savedIds = <String>{};
    for (final row in saved) {
      if (row is! Map) {
        throw const FormatException(
          'The server returned an invalid table-map position.',
        );
      }
      final value = Map<String, dynamic>.from(row);
      final id = value['id'];
      final x = value['position_x'];
      final y = value['position_y'];
      final updatedAt = value['updated_at'];
      if (id is! String ||
          !expectedIds.contains(id) ||
          !savedIds.add(id) ||
          x is! num ||
          y is! num ||
          updatedAt is! String ||
          DateTime.tryParse(updatedAt) == null ||
          !x.toDouble().isFinite ||
          !y.toDouble().isFinite ||
          x < 0 ||
          x > 1 ||
          y < 0 ||
          y > 1) {
        throw const FormatException(
          'The server returned an invalid table-map position.',
        );
      }
    }
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

  Future<String> fetchQrToken(String tableId) async {
    _requireSignedIn();
    final token = await _client.rpc(
      'get_cafe_dining_table_qr_token',
      params: {'p_table_id': tableId},
    );
    if (token is! String || token.isEmpty) {
      throw const FormatException('The server returned an invalid table QR.');
    }
    return token;
  }

  Future<String> regenerateQrToken(String tableId) async {
    _requireSignedIn();
    final token = await _client.rpc(
      'regenerate_cafe_dining_table_qr_token',
      params: {'p_table_id': tableId},
    );
    if (token is! String || token.isEmpty) {
      throw const FormatException('The server returned an invalid table QR.');
    }
    return token;
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

  static void _validatePricingMode(String pricingMode) {
    if (!pricingModes.contains(pricingMode)) {
      throw const FormatException('Choose a supported table pricing mode.');
    }
  }

  static void _validateMapLayout(List<CafeDiningTableMapChange> changes) {
    if (changes.isEmpty || changes.length > 500) {
      throw const FormatException(
        'Save a map layout containing between 1 and 500 tables.',
      );
    }
    final ids = <String>{};
    for (final change in changes) {
      if (change.id.isEmpty || !ids.add(change.id)) {
        throw const FormatException(
          'A table can appear only once in a map layout.',
        );
      }
      if (!change.x.isFinite ||
          !change.y.isFinite ||
          change.x < 0 ||
          change.x > 1 ||
          change.y < 0 ||
          change.y > 1 ||
          !change.expectedX.isFinite ||
          !change.expectedY.isFinite ||
          change.expectedX < 0 ||
          change.expectedX > 1 ||
          change.expectedY < 0 ||
          change.expectedY > 1) {
        throw const FormatException(
          'A table position is outside the floor map.',
        );
      }
    }

    final minimumHorizontalGap = mapTableWidth / mapCanvasWidth;
    final minimumVerticalGap = mapTableHeight / mapCanvasHeight;
    for (var firstIndex = 0; firstIndex < changes.length; firstIndex++) {
      final first = changes[firstIndex];
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < changes.length;
        secondIndex++
      ) {
        final second = changes[secondIndex];
        if ((first.x - second.x).abs() < minimumHorizontalGap &&
            (first.y - second.y).abs() < minimumVerticalGap) {
          throw const FormatException(
            'Separate overlapping tables before saving the map.',
          );
        }
      }
    }
  }
}
