import 'package:flutter/widgets.dart';

/// App-wide language context. Untranslated labels intentionally fall back to English.
/// This does not replace the full Flutter localization/dictionary migration.
class AppLanguage extends InheritedWidget {
  const AppLanguage({super.key, required this.code, required super.child});
  final String code;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLanguage>()?.code ?? 'en';

  static bool isRtl(String code) => code == 'ar' || code == 'ku_sorani';

  static const Map<String, Map<String, String>> _labels = {
    'ar': {
      'Motel Guest Services': 'خدمات ضيوف النزل',
      'Room QR unavailable': 'رمز الغرفة غير متاح',
      'Try again': 'إعادة المحاولة',
      'Room identified. Guest stay verification is required before ordering or viewing private information.': 'تم التعرف على الغرفة. يجب التحقق من إقامة الضيف قبل الطلب أو عرض المعلومات الخاصة.',
      'View Menu': 'عرض القائمة',
      'Order Food & Drinks': 'طلب الطعام والمشروبات',
      'Check Order Status': 'متابعة حالة الطلب',
      'Schedule Special Meal': 'جدولة وجبة خاصة',
      'Check Room Bill': 'عرض فاتورة الغرفة',
      'Call Employee': 'استدعاء موظف',
      'Requires verified guest stay': 'يتطلب إقامة ضيف مؤكدة',

      'Language': 'اللغة', 'Dashboard': 'لوحة التحكم', 'Tables': 'الطاولات',
      'Table Orders': 'طلبات الطاولات', 'Motel Orders': 'طلبات النزل',
      'Kitchen': 'المطبخ', 'Menu': 'القائمة', 'Customers': 'الزبائن',
      'Employees': 'الموظفون', 'Notifications': 'الإشعارات',
      'Reports': 'التقارير', 'Settings & Rules': 'الإعدادات والقواعد',
      'Your workspace': 'مساحة عملك', 'Quick access': 'الوصول السريع',
      'Find a workspace': 'ابحث عن قسم',
      'Rooms': 'الغرف', 'Scheduled Meals': 'الوجبات المجدولة', 'Rooms, Villas & Chalets': 'الغرف والفلل والشاليهات', 'Room number / unique label': 'رقم الغرفة / الرمز الفريد', 'Room name': 'اسم الغرفة', 'Accommodation type': 'نوع الإقامة', 'Add / Update Room': 'إضافة / تحديث غرفة', 'Registered accommodations': 'أماكن الإقامة المسجلة', 'Scheduled Special Meals': 'الوجبات الخاصة المجدولة', 'Registered room / villa number': 'رقم الغرفة أو الفيلا المسجلة', 'Meal, dishes and special instructions': 'الوجبة والأطباق والتعليمات الخاصة', 'Choose delivery date and time': 'اختر تاريخ ووقت التوصيل', 'Create scheduled request': 'إنشاء طلب مجدول', 'Scheduled requests': 'الطلبات المجدولة', 'Saving…': 'جارٍ الحفظ…', 'Active': 'نشط', 'Disabled': 'معطل',
    },
    'ku_badini': {
      'Motel Guest Services': 'Xizmetên mêvanên motêlê',
      'Room QR unavailable': 'Koda QR ya odê nayê dîtin',
      'Try again': 'Dîsa biceribîne',
      'View Menu': 'Menûyê bibîne',
      'Order Food & Drinks': 'Xwarin û vexwarinan bixwaze',
      'Check Order Status': 'Rewşa fermanê bibîne',
      'Schedule Special Meal': 'Xwarina taybet plan bike',
      'Check Room Bill': 'Hesabê odê bibîne',
      'Call Employee': 'Gazî karmendî bike',
      'Requires verified guest stay': 'Pêdivî bi piştrastkirina mayîna mêvan heye',

      'Language': 'Ziman', 'Dashboard': 'Panela rêvebirinê',
      'Tables': 'Mase', 'Table Orders': 'Fermanên masê',
      'Motel Orders': 'Fermanên motêlê', 'Kitchen': 'Mitbax',
      'Menu': 'Menû', 'Customers': 'Mişterî', 'Employees': 'Karker',
      'Notifications': 'Agahdarî', 'Reports': 'Rapor',
      'Your workspace': 'Cihê karê te', 'Quick access': 'Gihîştina bilez',
      'Find a workspace': 'Beşekê bibîne',
      'Rooms': 'Ode', 'Scheduled Meals': 'Xwarinên plankirî', 'Rooms, Villas & Chalets': 'Ode, vîla û şalet', 'Room number / unique label': 'Hejmara odê', 'Room name': 'Navê odê', 'Accommodation type': 'Cureyê cihê mayînê', 'Add / Update Room': 'Ode zêde bike / nû bike', 'Registered accommodations': 'Cihên tomarkirî', 'Scheduled Special Meals': 'Xwarinên taybet ên plankirî', 'Registered room / villa number': 'Hejmara ode / vîlayê', 'Meal, dishes and special instructions': 'Xwarin û daxwazên taybet', 'Choose delivery date and time': 'Roj û dema gihandinê hilbijêre', 'Create scheduled request': 'Daxwaza plankirî çêbike', 'Scheduled requests': 'Daxwazên plankirî', 'Saving…': 'Tê tomarkirin…', 'Active': 'Çalak', 'Disabled': 'Neçalak',
    },
    'ku_sorani': {
      'Motel Guest Services': 'خزمەتگوزارییەکانی میوانی مۆتێل',
      'Room QR unavailable': 'کۆدی ژوور بەردەست نییە',
      'Try again': 'دووبارە هەوڵ بدە',
      'View Menu': 'بینینی مێنیو',
      'Order Food & Drinks': 'داواکردنی خواردن و خواردنەوە',
      'Check Order Status': 'پشکنینی دۆخی داواکاری',
      'Schedule Special Meal': 'دانانی کاتی خواردنی تایبەت',
      'Check Room Bill': 'بینینی پسووڵەی ژوور',
      'Call Employee': 'بانگکردنی کارمەند',
      'Requires verified guest stay': 'پێویستی بە پشتڕاستکردنەوەی مانەوەی میوان هەیە',

      'Language': 'زمان', 'Dashboard': 'داشبۆرد', 'Tables': 'مێزەکان',
      'Table Orders': 'داواکارییەکانی مێز', 'Motel Orders': 'داواکارییەکانی مۆتێل',
      'Kitchen': 'چێشتخانە', 'Menu': 'مێنیو', 'Customers': 'کڕیارەکان',
      'Employees': 'کارمەندان', 'Notifications': 'ئاگادارکردنەوەکان',
      'Reports': 'ڕاپۆرتەکان', 'Your workspace': 'شوێنی کارەکەت',
      'Quick access': 'دەستگەیشتنی خێرا', 'Find a workspace': 'بەشێک بدۆزەوە',
    },
  };

  static String label(String code, String english) =>
      _labels[code]?[english] ?? english;

  @override
  bool updateShouldNotify(AppLanguage oldWidget) => code != oldWidget.code;
}
