import 'package:flutter/foundation.dart';

/// In-memory menu demonstration. No database writes or authoritative pricing.
class PreviewMenuItem {
  const PreviewMenuItem(
      {required this.name,
      required this.barcode,
      required this.normalPrice,
      required this.tourismPrice});
  final String name;
  final String barcode;
  final int normalPrice;
  final int tourismPrice;
  int priceFor({required bool tourism}) => tourism ? tourismPrice : normalPrice;
}

class LocalMenuPreview extends ChangeNotifier {
  LocalMenuPreview._();
  static final LocalMenuPreview instance = LocalMenuPreview._();
  final List<PreviewMenuItem> items = [];

  bool add(PreviewMenuItem item) {
    if (item.name.trim().isEmpty || item.name.trim().length > 200 ||
        item.barcode.trim().isEmpty || item.barcode.trim().length > 100 ||
        item.normalPrice < 0 || item.normalPrice > 1000000000 ||
        item.tourismPrice < 0 || item.tourismPrice > 1000000000 ||
        items.any((p) => p.barcode.trim() == item.barcode.trim())) {
      return false;
    }
    items.add(item);
    notifyListeners();
    return true;
  }

  PreviewMenuItem? findByBarcode(String barcode) {
    for (final item in items) {
      if (item.barcode.trim() == barcode.trim()) return item;
    }
    return null;
  }

  void remove(PreviewMenuItem item) {
    if (items.remove(item)) notifyListeners();
  }
}
