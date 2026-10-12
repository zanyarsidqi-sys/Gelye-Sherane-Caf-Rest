/// Deterministic pricing rules shared by table, motel, and barcode order flows.
/// The server must independently enforce the chosen price and permissions.
enum CafePriceMode { normal, tourism }

class CafeMenuPrice {
  const CafeMenuPrice({
    required this.productId,
    required this.normalPriceIqd,
    required this.tourismPriceIqd,
  });

  final String productId;
  final int normalPriceIqd;
  final int tourismPriceIqd;

  int priceFor(CafePriceMode mode) {
    if (normalPriceIqd < 0 || tourismPriceIqd < 0) {
      throw StateError('Product prices cannot be negative.');
    }
    return mode == CafePriceMode.tourism
        ? tourismPriceIqd
        : normalPriceIqd;
  }
}

class CafeOrderPricing {
  const CafeOrderPricing._();

  static CafePriceMode modeForTable({bool tourismEnabled = false}) =>
      tourismEnabled ? CafePriceMode.tourism : CafePriceMode.normal;

  static CafePriceMode modeForMotel() => CafePriceMode.tourism;

  static int lineTotal({required int unitPriceIqd, required int quantity}) {
    if (unitPriceIqd < 0 || quantity <= 0) {
      throw ArgumentError('Price must be nonnegative and quantity positive.');
    }
    return unitPriceIqd * quantity;
  }
}
