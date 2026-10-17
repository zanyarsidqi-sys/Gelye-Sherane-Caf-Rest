import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelye_sherane_cafe/cafe_language.dart';
import 'package:gelye_sherane_cafe/main.dart';
import 'package:gelye_sherane_cafe/cafe_translations.dart';

class MemoryLanguageStore implements CafeLanguageStore {
  String? value;
  bool fail=false;
  @override Future<String?> read() async { if(fail)throw StateError('blocked'); return value; }
  @override Future<void> write(String code) async { if(fail)throw StateError('blocked'); value=code; }
}
void main() {
  testWidgets('application supports the Badini default on a phone-sized screen', (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous=cafeLanguage.language;
    cafeLanguage.language=CafeLanguage.badini;
    await tester.pumpWidget(const CafeApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cafe-language-selector')),findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(CafeLandingPage))),TextDirection.rtl);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
    cafeLanguage.language=previous;
  });

  test('new customers and staff default to Badini; remembered language wins',() async {
    final storage=MemoryLanguageStore();
    final controller=CafeLanguageController(store:storage);
    expect(controller.language,CafeLanguage.badini);
    await controller.load();
    expect(controller.language,CafeLanguage.badini);
    await controller.select(CafeLanguage.arabic);
    final restored=CafeLanguageController(store:storage);
    await restored.load();
    expect(restored.language,CafeLanguage.arabic);
    storage.value='invalid';
    await restored.load();
    expect(restored.language,CafeLanguage.badini);
  });
  test('blocked storage keeps language selection usable',() async {
    final controller=CafeLanguageController(store:MemoryLanguageStore()..fail=true);
    await controller.load();
    expect(controller.language,CafeLanguage.badini);
    await controller.select(CafeLanguage.english);
    expect(controller.language,CafeLanguage.english);
    expect(controller.saved,false);
  });
  test('latest preference survives rapid changes',() async {
    final storage=MemoryLanguageStore();
    final controller=CafeLanguageController(store:storage);
    await Future.wait([controller.select(CafeLanguage.arabic),controller.select(CafeLanguage.english)]);
    expect(storage.value,'en');
    expect(controller.language,CafeLanguage.english);
  });
  testWidgets('selector changes text and direction without replacing page state', (tester) async {
    final controller=CafeLanguageController(store:MemoryLanguageStore());
    final field=TextEditingController(text:'Guest Sara');
    await tester.pumpWidget(ListenableBuilder(listenable:controller,builder:(context,_) =>
      CafeLanguageScope(controller:controller,child:MaterialApp(
        builder:(context,child)=>Directionality(textDirection:controller.language.isRtl?TextDirection.rtl:TextDirection.ltr,child:child!),
        home:Scaffold(appBar:AppBar(actions:const [CafeLanguageButton()]),
          body:Column(children:[const CafeText('Request bill'),TextField(controller:field)]))))));
    await tester.pumpAndSettle();
    expect(find.text(cafeTranslations['ku']!['Request bill']!),findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(TextField))),TextDirection.rtl);
    await tester.tap(find.byKey(const ValueKey('cafe-language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Request bill'),findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(TextField))),TextDirection.ltr);
    expect(field.text,'Guest Sara');
    await tester.tap(find.byKey(const ValueKey('cafe-language-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('طلب الفاتورة'),findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(TextField))),TextDirection.rtl);
    expect(field.text,'Guest Sara');
    await tester.pumpWidget(const SizedBox());
    field.dispose();
    controller.dispose();
  });
}
