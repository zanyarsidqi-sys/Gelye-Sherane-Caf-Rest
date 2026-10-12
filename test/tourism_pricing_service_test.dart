import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_cafe_rest/services/tourism_pricing_service.dart';

void main() {
  const product = CafeMenuPrice(
    productId: 'barcode-product-1',
    normalPriceIqd: 3000,
    tourismPriceIqd: 4500,
  );

  test('Tables default to normal pricing', () {
    expect(CafeOrderPricing.modeForTable(), CafePriceMode.normal);
    expect(product.priceFor(CafeOrderPricing.modeForTable()), 3000);
  });

  test('Tourism table and motel use same product with tourism price', () {
    expect(product.priceFor(CafeOrderPricing.modeForTable(tourismEnabled: true)), 4500);
    expect(product.priceFor(CafeOrderPricing.modeForMotel()), 4500);
    expect(product.productId, 'barcode-product-1');
  });

  test('Order line total uses captured price and quantity', () {
    expect(CafeOrderPricing.lineTotal(unitPriceIqd: 4500, quantity: 3), 13500);
    expect(() => CafeOrderPricing.lineTotal(unitPriceIqd: 4500, quantity: 0), throwsArgumentError);
  });
}
