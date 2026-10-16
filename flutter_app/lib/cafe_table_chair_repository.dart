import 'package:supabase_flutter/supabase_flutter.dart';

class CafeChairTableState {
  const CafeChairTableState({
    required this.tableId,
    required this.name,
    required this.area,
    required this.status,
    required this.baseChairs,
    required this.currentChairs,
    required this.protectedSeats,
  });

  factory CafeChairTableState.fromJson(Map<String, dynamic> json) {
    return CafeChairTableState(
      tableId: json['table_id'] as String,
      name: json['name'] as String,
      area: json['area'] as String,
      status: json['status'] as String,
      baseChairs: (json['base_chairs'] as num).toInt(),
      currentChairs: (json['current_chairs'] as num).toInt(),
      protectedSeats: (json['protected_seats'] as num?)?.toInt(),
    );
  }

  final String tableId;
  final String name;
  final String area;
  final String status;
  final int baseChairs;
  final int currentChairs;
  final int? protectedSeats;
}

class CafeChairMovement {
  const CafeChairMovement({
    required this.id,
    required this.action,
    required this.sourceTableId,
    required this.destinationTableId,
    required this.quantity,
    required this.reason,
    required this.beforeState,
    required this.afterState,
    required this.actorId,
    required this.createdAt,
  });

  factory CafeChairMovement.fromJson(Map<String, dynamic> json) {
    return CafeChairMovement(
      id: json['id'] as String,
      action: json['action'] as String,
      sourceTableId: json['source_table_id'] as String?,
      destinationTableId: json['destination_table_id'] as String?,
      quantity: (json['quantity'] as num?)?.toInt(),
      reason: json['reason'] as String,
      beforeState: Map<String, dynamic>.from(json['before_state'] as Map),
      afterState: Map<String, dynamic>.from(json['after_state'] as Map),
      actorId: json['actor_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String action;
  final String? sourceTableId;
  final String? destinationTableId;
  final int? quantity;
  final String reason;
  final Map<String, dynamic> beforeState;
  final Map<String, dynamic> afterState;
  final String actorId;
  final DateTime createdAt;
}

class CafeChairManagementSnapshot {
  const CafeChairManagementSnapshot({
    required this.poolConfigured,
    required this.availableChairs,
    required this.tables,
    required this.movements,
  });

  factory CafeChairManagementSnapshot.fromJson(Map<String, dynamic> json) {
    final pool = Map<String, dynamic>.from(json['pool'] as Map);
    return CafeChairManagementSnapshot(
      poolConfigured: pool['is_configured'] as bool,
      availableChairs: (pool['available_chairs'] as num).toInt(),
      tables: (json['tables'] as List)
          .map(
            (row) => CafeChairTableState.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
      movements: (json['movements'] as List)
          .map(
            (row) => CafeChairMovement.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  final bool poolConfigured;
  final int availableChairs;
  final List<CafeChairTableState> tables;
  final List<CafeChairMovement> movements;
}

class CafeTableChairRepository {
  const CafeTableChairRepository(this._client);

  static const operations = {'give', 'take', 'transfer'};

  final SupabaseClient _client;

  Future<CafeChairManagementSnapshot> fetchManagement() async {
    _requireSignedIn();
    final result = await _client.rpc('get_cafe_chair_management');
    if (result is! Map) {
      throw const FormatException(
        'The server returned invalid chair-management data.',
      );
    }
    return CafeChairManagementSnapshot.fromJson(
      Map<String, dynamic>.from(result),
    );
  }

  Future<void> reconcileSparePool({
    required String requestId,
    required int availableChairs,
    required String reason,
  }) async {
    _validateCount(availableChairs, maximum: 10000);
    _validateReason(reason);
    _requireSignedIn();
    await _client.rpc(
      'set_cafe_spare_chair_count',
      params: {
        'p_request_id': requestId,
        'p_available_chairs': availableChairs,
        'p_reason': reason.trim(),
      },
    );
  }

  Future<void> setProtectedSeats({
    required String requestId,
    required String tableId,
    required int protectedSeats,
    required String reason,
  }) async {
    _validateCount(protectedSeats, maximum: 100);
    _validateReason(reason);
    _requireSignedIn();
    await _client.rpc(
      'set_cafe_table_protected_seats',
      params: {
        'p_request_id': requestId,
        'p_table_id': tableId,
        'p_protected_seats': protectedSeats,
        'p_reason': reason.trim(),
      },
    );
  }

  Future<void> moveChairs({
    required String requestId,
    required String operation,
    required String? sourceTableId,
    required String? destinationTableId,
    required int quantity,
    required String reason,
  }) async {
    if (!operations.contains(operation)) {
      throw const FormatException('Choose a supported chair movement.');
    }
    if (quantity < 1 || quantity > 100) {
      throw const FormatException('Quantity must be between 1 and 100.');
    }
    if ((operation == 'give' &&
            (sourceTableId != null || destinationTableId == null)) ||
        (operation == 'take' &&
            (sourceTableId == null || destinationTableId != null)) ||
        (operation == 'transfer' &&
            (sourceTableId == null ||
                destinationTableId == null ||
                sourceTableId == destinationTableId))) {
      throw const FormatException(
        'Choose valid and distinct source and destination tables.',
      );
    }
    _validateReason(reason);
    _requireSignedIn();
    await _client.rpc(
      'move_cafe_table_chairs',
      params: {
        'p_request_id': requestId,
        'p_operation': operation,
        'p_source_table_id': sourceTableId,
        'p_destination_table_id': destinationTableId,
        'p_quantity': quantity,
        'p_reason': reason.trim(),
      },
    );
  }

  String _requireSignedIn() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in again to manage table chairs.');
    }
    return userId;
  }

  static void _validateCount(int count, {required int maximum}) {
    if (count < 0 || count > maximum) {
      throw FormatException('Count must be between 0 and $maximum.');
    }
  }

  static void _validateReason(String reason) {
    if (reason.trim().isEmpty || reason.trim().runes.length > 300) {
      throw const FormatException(
        'Enter a reason between 1 and 300 characters.',
      );
    }
  }
}
