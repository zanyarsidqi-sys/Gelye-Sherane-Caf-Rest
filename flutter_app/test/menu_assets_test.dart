import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_menu_assets.dart';
import 'package:gelye_sherane_cafe/cafe_menu_workspace.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Owner zero is preserved when decoding saved products', () {
    final product=CafeMenuItem.fromJson({'id':'p','name':'Tea','category':'Drinks','description':'','price_iqd':1000,'owner_price_iqd':0,'tourism_price_iqd':2000,'available':true});
    expect(product.ownerPriceIqd,0);
  });
  test('Owner zero passes validation while negative Owner is rejected', () async {
    final client=SupabaseClient('https://example.supabase.co','test-key');
    final store=SupabaseCafeMenuStore(client);
    Future<void> save(int owner)=>store.save(name:'Tea',category:'Drinks',description:'',priceIqd:1000,tourismPriceIqd:2000,ownerPriceIqd:owner,stationIds:[],available:true);
    await expectLater(save(-1),throwsA(isA<FormatException>()));
    await expectLater(save(0),throwsA(isA<AuthException>()));
    await client.dispose();
  });
  testWidgets('categories require a connection before writes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:Scaffold(body:SingleChildScrollView(child:CafeMenuAssets(images:false)))));
    await tester.pumpAndSettle();
    expect(find.text('Product Categories'),findsOneWidget);
    expect(find.textContaining('Unable to load'),findsOneWidget);
    final add=tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Add category'));
    expect(add.onPressed,isNull);
  });
}
