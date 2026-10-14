import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuProduct {
  const MenuProduct({
    required this.id,
    required this.name,
    required this.barcode,
    required this.description,
    required this.category,
    required this.normalPriceIqd,
    required this.tourismPriceIqd,
    required this.ownerPriceIqd,
    required this.isActive,
    required this.imagePath,
    required this.preparationMinutes,
    required this.dietaryTags,
    required this.displayOrder,
    required this.version,
    required this.stationKey,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String barcode;
  final String description;
  final String category;
  final int normalPriceIqd;
  final int tourismPriceIqd;
  final int? ownerPriceIqd;
  final bool isActive;
  final String? imagePath;
  final int? preparationMinutes;
  final List<String> dietaryTags;
  final int displayOrder;
  final int version;
  final String? stationKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MenuProduct.fromJson(Map<String, dynamic> json) => MenuProduct(
        id: _asInt(json['id']),
        name: '${json['name'] ?? ''}',
        barcode: '${json['barcode'] ?? ''}',
        description: '${json['description'] ?? ''}',
        category: '${json['category'] ?? 'Uncategorized'}',
        normalPriceIqd: _asInt(json['normal_price_iqd']),
        tourismPriceIqd: _asInt(json['tourism_price_iqd']),
        ownerPriceIqd: json['owner_price_iqd'] == null
            ? null
            : _asInt(json['owner_price_iqd']),
        isActive: json['is_active'] == true,
        imagePath: _asNullableString(json['image_path']),
        preparationMinutes: json['preparation_minutes'] == null
            ? null
            : _asInt(json['preparation_minutes']),
        dietaryTags: _asStringList(json['dietary_tags']),
        displayOrder: _asInt(json['display_order']),
        version: _asInt(json['version'], fallback: 1),
        stationKey: _asNullableString(json['station_key']),
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
        updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
      );
}

class MenuProductDraft {
  const MenuProductDraft({
    required this.name,
    required this.barcode,
    required this.description,
    required this.category,
    required this.normalPriceIqd,
    required this.tourismPriceIqd,
    required this.ownerPriceIqd,
    required this.imagePath,
    required this.preparationMinutes,
    required this.dietaryTags,
    required this.displayOrder,
    required this.stationKey,
  });

  final String name;
  final String barcode;
  final String description;
  final String category;
  final int normalPriceIqd;
  final int tourismPriceIqd;
  final int? ownerPriceIqd;
  final String? imagePath;
  final int? preparationMinutes;
  final List<String> dietaryTags;
  final int displayOrder;
  final String? stationKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name.trim(),
        'barcode': barcode.trim(),
        'description': description.trim(),
        'category': category.trim().isEmpty ? 'Uncategorized' : category.trim(),
        'normal_price_iqd': normalPriceIqd,
        'tourism_price_iqd': tourismPriceIqd,
        'owner_price_iqd': ownerPriceIqd,
        'image_path': imagePath,
        'preparation_minutes': preparationMinutes,
        'dietary_tags': dietaryTags,
        'display_order': displayOrder,
        'station_key': stationKey,
      };
}

class MenuRevision {
  const MenuRevision({
    required this.id,
    required this.productId,
    required this.baseVersion,
    required this.payload,
    required this.submittedBy,
    required this.createdAt,
  });

  final String id;
  final int? productId;
  final int? baseVersion;
  final Map<String, dynamic> payload;
  final String submittedBy;
  final DateTime? createdAt;

  factory MenuRevision.fromJson(Map<String, dynamic> json) => MenuRevision(
        id: '${json['id']}',
        productId: json['product_id'] == null ? null : _asInt(json['product_id']),
        baseVersion:
            json['base_version'] == null ? null : _asInt(json['base_version']),
        payload: Map<String, dynamic>.from(
          json['payload'] as Map? ?? const <String, dynamic>{},
        ),
        submittedBy: '${json['submitted_by'] ?? ''}',
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      );
}

class MenuCategorySummary {
  const MenuCategorySummary({
    required this.name,
    required this.productCount,
    required this.activeCount,
  });

  final String name;
  final int productCount;
  final int activeCount;

  factory MenuCategorySummary.fromJson(Map<String, dynamic> json) =>
      MenuCategorySummary(
        name: '${json['category'] ?? ''}',
        productCount: _asInt(json['product_count']),
        activeCount: _asInt(json['active_count']),
      );
}

class MenuPreparationStation {
  const MenuPreparationStation({
    required this.key,
    required this.name,
    required this.enabled,
  });

  final String key;
  final String name;
  final bool enabled;

  factory MenuPreparationStation.fromJson(Map<String, dynamic> json) =>
      MenuPreparationStation(
        key: '${json['station_key'] ?? ''}',
        name: '${json['display_name'] ?? json['station_key'] ?? ''}',
        enabled: json['enabled'] == true,
      );
}

class MenuManagementService {
  MenuManagementService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String imageBucket = 'gs-menu-product-images';
  static const int maximumImageBytes = 8 * 1024 * 1024;
  static const Set<String> allowedDietaryTags = <String>{
    'vegetarian',
    'vegan',
    'gluten_free',
    'spicy',
    'halal',
  };

  final SupabaseClient _client;

  Future<List<MenuProduct>> loadProducts() async {
    final response = await _client.rpc('gs_menu_admin_products');
    return _asRows(response).map(MenuProduct.fromJson).toList(growable: false);
  }

  Future<List<MenuCategorySummary>> loadCategories() async {
    final response = await _client.rpc('gs_menu_category_summary');
    return _asRows(response)
        .map(MenuCategorySummary.fromJson)
        .toList(growable: false);
  }

  Future<List<MenuPreparationStation>> loadStations() async {
    final response = await _client.rpc('gs_menu_station_directory');
    return _asRows(response)
        .map(MenuPreparationStation.fromJson)
        .toList(growable: false);
  }

  Future<List<MenuRevision>> loadPendingRevisions() async {
    final response = await _client
        .from('gs_menu_product_revisions')
        .select('id,product_id,base_version,payload,submitted_by,created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .limit(200);
    return _asRows(response).map(MenuRevision.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadProductHistory(int productId) async {
    final response = await _client
        .from('gs_menu_audit_events')
        .select('id,revision_id,actor_id,action,request_id,before_state,after_state,occurred_at')
        .eq('product_id', productId)
        .order('occurred_at', ascending: false)
        .limit(100);
    return _asRows(response);
  }

  Future<String> uploadProductImage(PlatformFile file) async {
    final userId = _client.auth.currentUser?.id;
    final Uint8List? bytes = file.bytes;
    if (userId == null) {
      throw StateError('Sign in again before uploading a menu photo.');
    }
    if (bytes == null || bytes.isEmpty || bytes.length > maximumImageBytes) {
      throw StateError('Choose an image smaller than 8 MB and try again.');
    }

    final extension = file.extension?.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    if (contentType == null) {
      throw StateError('Use a JPG, PNG, or WebP image.');
    }

    final normalizedExtension = extension == 'jpeg' ? 'jpg' : extension;
    final path = '$userId/${newRequestId()}.$normalizedExtension';
    await _client.storage.from(imageBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return path;
  }

  String? publicImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    return _client.storage.from(imageBucket).getPublicUrl(imagePath);
  }

  Future<String> submitProductRevision({
    required MenuProductDraft draft,
    required String idempotencyKey,
    int? productId,
    int? expectedVersion,
  }) async {
    final response = await _client.rpc(
      'gs_menu_submit_product_revision',
      params: <String, dynamic>{
        'p_product_id': productId,
        'p_expected_version': expectedVersion,
        'p_payload': draft.toJson(),
        'p_idempotency_key': idempotencyKey,
      },
    );
    if (response is! String || response.trim().isEmpty) {
      throw StateError('The server did not return a menu revision ID.');
    }
    return response;
  }

  Future<Map<String, dynamic>> reviewProductRevision({
    required String revisionId,
    required String decision,
    required int? expectedVersion,
    String? note,
  }) async {
    final response = await _client.rpc(
      'gs_menu_review_product_revision',
      params: <String, dynamic>{
        'p_revision_id': revisionId,
        'p_decision': decision,
        'p_expected_version': expectedVersion,
        'p_note': note,
      },
    );
    if (response is! Map) {
      throw StateError('The server returned an invalid review result.');
    }
    return Map<String, dynamic>.from(response);
  }

  Future<int> setProductAvailability({
    required MenuProduct product,
    required bool isActive,
    required String requestId,
  }) async {
    final response = await _client.rpc(
      'gs_menu_set_product_availability',
      params: <String, dynamic>{
        'p_product_id': product.id,
        'p_is_active': isActive,
        'p_expected_version': product.version,
        'p_request_id': requestId,
      },
    );
    if (response is! num) {
      throw StateError('The server did not confirm the availability change.');
    }
    return response.toInt();
  }

  static String newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

int _asInt(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const <String>[];
}

List<Map<String, dynamic>> _asRows(Object? response) {
  if (response is! List) {
    throw StateError('The server returned an invalid menu response.');
  }
  return response
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
