import 'package:supabase_flutter/supabase_flutter.dart';

class CafeWorkspaceRecord {
  const CafeWorkspaceRecord({
    required this.id,
    required this.sectionKey,
    required this.subcardKey,
    required this.title,
    required this.details,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CafeWorkspaceRecord.fromJson(Map<String, dynamic> json) {
    return CafeWorkspaceRecord(
      id: json['id'] as String,
      sectionKey: json['section_key'] as String,
      subcardKey: json['subcard_key'] as String,
      title: json['title'] as String,
      details: json['details'] as String? ?? '',
      status: json['status'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String sectionKey;
  final String subcardKey;
  final String title;
  final String details;
  final String status;
  final double? amount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CafeWorkspaceRepository {
  const CafeWorkspaceRepository(this._client);

  static final _keyPattern = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');
  static const _recordStatuses = {
    'open',
    'in_progress',
    'completed',
    'cancelled',
  };

  final SupabaseClient _client;

  Future<List<CafeWorkspaceRecord>> fetchRecords() async {
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      final page = await _client
          .from('cafe_workspace_records')
          .select(
            'id,section_key,subcard_key,title,details,status,amount,currency,'
            'created_at,updated_at',
          )
          .order('updated_at', ascending: false)
          .order('id')
          .range(offset, offset + pageSize - 1);

      rows.addAll(page);
      if (page.length < pageSize) {
        break;
      }
      offset += pageSize;
    }

    return rows
        .map(
          (row) => CafeWorkspaceRecord.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<void> createRecord({
    required String sectionKey,
    required String subcardKey,
    required String title,
    required String details,
    required double? amount,
  }) async {
    final normalizedSectionKey = _validatedKey(sectionKey, 'section');
    final normalizedSubcardKey = _validatedKey(subcardKey, 'subcard');
    final normalizedTitle = title.trim();
    final titleLength = normalizedTitle.runes.length;
    if (titleLength == 0 || titleLength > 160) {
      throw const FormatException(
        'Record title must contain between 1 and 160 characters.',
      );
    }
    if (amount != null && (!amount.isFinite || amount.abs() >= 1000000000000)) {
      throw const FormatException('Amount is outside the supported range.');
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in again to add a workspace record.');
    }

    await _client.from('cafe_workspace_records').insert({
      'section_key': normalizedSectionKey,
      'subcard_key': normalizedSubcardKey,
      'title': normalizedTitle,
      'details': details,
      'amount': amount,
      'created_by': userId,
      'updated_by': userId,
    });
  }

  Future<void> updateStatus({
    required String recordId,
    required String status,
  }) async {
    if (!_recordStatuses.contains(status)) {
      throw const FormatException('Choose a supported record status.');
    }
    _requireSignedIn();

    await _client
        .from('cafe_workspace_records')
        .update({'status': status})
        .eq('id', recordId)
        .select('id')
        .single();
  }

  Future<void> deleteRecord(String recordId) async {
    _requireSignedIn();

    await _client
        .from('cafe_workspace_records')
        .delete()
        .eq('id', recordId)
        .select('id')
        .single();
  }

  RealtimeChannel subscribe(void Function() onChange) {
    return _client
        .channel('cafe-workspace-records')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cafe_workspace_records',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _client.removeChannel(channel);

  static String _validatedKey(String value, String label) {
    final normalized = value.trim();
    if (!_keyPattern.hasMatch(normalized)) {
      throw FormatException(
        'The $label key must use lowercase letters, numbers, and underscores.',
      );
    }
    return normalized;
  }

  void _requireSignedIn() {
    if (_client.auth.currentUser == null) {
      throw const AuthException('Sign in again to change workspace records.');
    }
  }
}
