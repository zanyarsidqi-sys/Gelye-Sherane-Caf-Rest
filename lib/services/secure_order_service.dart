import 'package:supabase_flutter/supabase_flutter.dart';

/// Phase 3 server-priced order foundation.
/// Activate only after reviewing and applying the optional gs_ SQL migration.
/// Never send a selling price from the client; the database RPC selects it.
class SecureOrderService {
  SecureOrderService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Creates one order containing every cart line in one database transaction.
  Future<int> createCartOrder({
    required String destination,
    required bool isMotel,
    int? tableNumber,
    required List<Map<String, int>> items,
  }) async {
    if (items.isEmpty || items.length > 100) throw ArgumentError('Invalid cart size');
    final result = await _client.rpc('gs_create_cart_order', params: {
      'p_destination': destination.trim(),
      'p_is_motel': isMotel,
      'p_table_number': isMotel ? null : tableNumber,
      'p_items': items,
    });
    if (result is! num) throw StateError('Unexpected order ID');
    return result.toInt();
  }

  Future<int> createOrder({
    required String destination,
    required bool isMotel,
    required bool tourismMode,
    required int productId,
    required int quantity,
    int? tableNumber,
  }) async {
    if (destination.trim().isEmpty || destination.length > 120) {
      throw ArgumentError.value(destination, 'destination', 'Invalid destination');
    }
    if (productId <= 0 || quantity < 1 || quantity > 999) {
      throw ArgumentError('Invalid product or quantity');
    }
    final result = await _client.rpc('gs_create_order_for_destination', params: {
      'p_destination': destination.trim(),
      'p_is_motel': isMotel,
      'p_tourism_mode': isMotel || tourismMode,
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_table_number': isMotel ? null : tableNumber,
    });
    if (result is! num) {
      throw StateError('Unexpected order ID from server');
    }
    return result.toInt();
  }
}
