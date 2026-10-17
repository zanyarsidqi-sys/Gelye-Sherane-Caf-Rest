import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cafe_translations.dart';

enum CafeLanguage {
  english('en', 'English'),
  arabic('ar', 'العربية'),
  badini('ku', 'کوردی بادینی');
  const CafeLanguage(this.code, this.label);
  final String code, label;
  bool get isRtl => this != english;
}

abstract class CafeLanguageStore {
  Future<String?> read();
  Future<void> write(String code);
}
class DeviceCafeLanguageStore implements CafeLanguageStore {
  late final _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString('cafe.language.v1');
  @override
  Future<void> write(String code) => _preferences.setString('cafe.language.v1', code);
}
class CafeLanguageController extends ChangeNotifier {
  CafeLanguageController({CafeLanguageStore? store}) : _store = store ?? DeviceCafeLanguageStore();
  final CafeLanguageStore _store;
  CafeLanguage language = CafeLanguage.badini;
  bool saved = true;
  int _revision = 0;
  Future<void> _writes = Future<void>.value();
  Future<void> load() async {
    final revision = _revision;
    try {
      final code = await _store.read();
      if(revision != _revision)return;
      language = CafeLanguage.values.where((v)=>v.code==code).firstOrNull ?? CafeLanguage.badini;
      notifyListeners();
    } catch (_) { /* Storage restrictions must not block the app. */ }
  }
  Future<void> select(CafeLanguage value) {
    language=value;
    final revision=++_revision;
    saved=true;
    notifyListeners();
    // Serialize preference writes so a slower older choice cannot overwrite the latest.
    return _writes = _writes.then((_) async {
      try { await _store.write(value.code); }
      catch (_) { if(revision==_revision) { saved=false; notifyListeners(); } }
    });
  }
}
final cafeLanguage = CafeLanguageController();

class CafeLanguageScope extends InheritedNotifier<CafeLanguageController> {
  const CafeLanguageScope({super.key, required CafeLanguageController controller, required super.child}) : super(notifier:controller);
  static CafeLanguageController of(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<CafeLanguageScope>()?.notifier ?? cafeLanguage;
}
String cafeTranslate(BuildContext context, String text) =>
  translateCafeText(CafeLanguageScope.of(context).language.code, text);

/// Interface text only. Product names, guest notes, identifiers and financial
/// values must remain ordinary Text widgets.
class CafeText extends StatelessWidget {
  const CafeText(this.data, {super.key, this.style, this.strutStyle, this.textAlign,
    this.textDirection, this.locale, this.softWrap, this.overflow, this.textScaler,
    this.maxLines, this.semanticsLabel, this.textWidthBasis, this.textHeightBehavior,
    this.selectionColor});
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  @override
  Widget build(BuildContext context) => Text(cafeTranslate(context,data),
    style:style,strutStyle:strutStyle,textAlign:textAlign,textDirection:textDirection,
    locale:locale,softWrap:softWrap,overflow:overflow,textScaler:textScaler,
    maxLines:maxLines,semanticsLabel:semanticsLabel==null?null:cafeTranslate(context,semanticsLabel!),
    textWidthBasis:textWidthBasis,textHeightBehavior:textHeightBehavior,selectionColor:selectionColor);
}

class CafeLanguageButton extends StatelessWidget {
  const CafeLanguageButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller=CafeLanguageScope.of(context);
    return PopupMenuButton<CafeLanguage>(
      key:const ValueKey('cafe-language-selector'),
      tooltip:cafeTranslate(context,'Language'),
      icon:const Icon(Icons.language),
      initialValue:controller.language,
      onSelected:(language) async {
        await controller.select(language);
        if(context.mounted && !controller.saved) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            content:CafeText('Language changed for this session. Could not save your preference.')));
        }
      },
      itemBuilder:(_)=>[for(final language in CafeLanguage.values)
        CheckedPopupMenuItem(value:language,checked:controller.language==language,
          child:Text(language.label,textDirection:language.isRtl?TextDirection.rtl:TextDirection.ltr))],
    );
  }
}

class BadiniMaterialLocalizations extends DefaultMaterialLocalizations {
  const BadiniMaterialLocalizations();
  @override String get okButtonLabel => 'باشە';
  @override String get cancelButtonLabel => 'هەلوەشاندن';
  @override String get closeButtonLabel => 'گرتن';
  @override String get continueButtonLabel => 'بەردەوامبوون';
  @override String get saveButtonLabel => 'هەڵگرتن';
  @override String get deleteButtonTooltip => 'ژێبرن';
  @override String get backButtonTooltip => 'ڤەگەڕیان';
  @override String get nextPageTooltip => 'لاپەڕا دویڤدا';
  @override String get previousPageTooltip => 'لاپەڕا بەری';
  @override String get showMenuTooltip => 'نیشاندانا مێنیویێ';
  @override String get searchFieldLabel => 'لێگەڕیان';
  @override String get selectAllButtonLabel => 'هەلبژارتنا هەمی';
  @override String get copyButtonLabel => 'کۆپیکرن';
  @override String get cutButtonLabel => 'ژێکرن';
  @override String get pasteButtonLabel => 'پێڤەکرن';
  @override String get modalBarrierDismissLabel => 'گرتن';
  @override String get datePickerHelpText => 'مێژوویێ هەلبژێرە';
}

class BadiniMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const BadiniMaterialDelegate();
  @override bool isSupported(Locale locale) => locale.languageCode == 'ku';
  @override Future<MaterialLocalizations> load(Locale locale) =>
    SynchronousFuture<MaterialLocalizations>(const BadiniMaterialLocalizations());
  @override bool shouldReload(BadiniMaterialDelegate old) => false;
}

class BadiniCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const BadiniCupertinoLocalizations();
  @override String get cutButtonLabel => 'ژێکرن';
  @override String get copyButtonLabel => 'کۆپیکرن';
  @override String get pasteButtonLabel => 'پێڤەکرن';
  @override String get selectAllButtonLabel => 'هەلبژارتنا هەمی';
  @override String get clearButtonLabel => 'پاککرن';
  @override String get searchTextFieldPlaceholderLabel => 'لێگەڕیان';
  @override String get cancelButtonLabel => 'هەلوەشاندن';
  @override String get backButtonLabel => 'ڤەگەڕیان';
  @override String get modalBarrierDismissLabel => 'گرتن';
}
class BadiniCupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const BadiniCupertinoDelegate();
  @override bool isSupported(Locale locale) => locale.languageCode=='ku';
  @override Future<CupertinoLocalizations> load(Locale locale) =>
    SynchronousFuture<CupertinoLocalizations>(const BadiniCupertinoLocalizations());
  @override bool shouldReload(BadiniCupertinoDelegate old) => false;
}
