import 'package:flutter/foundation.dart';

/// Temporary in-memory demonstration only. Not connected to Supabase.
/// Never use these prices or order states for real payments or fulfillment.
enum PreviewOrderStatus { newOrder, preparing, ready, served, cancelled }

class PreviewOrder {
  PreviewOrder({required this.id, required this.destination,
    required this.isMotel, required this.tourism,
    required this.item, required this.quantity, required this.unitPrice});
  final DateTime createdAt = DateTime.now();
  final int id;
  final String destination;
  final bool isMotel;
  final bool tourism;
  final String item;
  final int quantity;
  final int unitPrice;
  PreviewOrderStatus status = PreviewOrderStatus.newOrder;
  int get total => quantity * unitPrice;
}

class LocalOrderPreview extends ChangeNotifier {
  LocalOrderPreview._();
  static final LocalOrderPreview instance = LocalOrderPreview._();
  final List<PreviewOrder> orders = [];
  int _nextId = 1;

  void add({required String destination, required bool isMotel,
    required bool tourism, required String item, required int quantity,
    required int unitPrice}) {
    orders.insert(0, PreviewOrder(id: _nextId++, destination: destination,
      isMotel: isMotel, tourism: isMotel || tourism,
      item: item, quantity: quantity, unitPrice: unitPrice));
    notifyListeners();
  }

  void changeStatus(PreviewOrder order, PreviewOrderStatus status) {
    if (!orders.contains(order)) return;
    order.status = status;
    notifyListeners();
  }

  void clear() { orders.clear(); notifyListeners(); }
}
