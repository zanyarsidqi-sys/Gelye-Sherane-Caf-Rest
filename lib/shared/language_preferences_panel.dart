import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local language selection and translation preview.
/// Full app localization is a separate integration task.
class LanguagePreferencesPanel extends StatefulWidget {
  const LanguagePreferencesPanel({super.key});

  @override
  State<LanguagePreferencesPanel> createState() =>
      _LanguagePreferencesPanelState();
}

class _LanguagePreferencesPanelState extends State<LanguagePreferencesPanel> {
  static const _key = 'gelye_cafe_language_v1';
  static const _languages = <String, String>{
    'en': 'English',
    'ar': 'العربية — Arabic',
    'ku_badini': 'Kurdî — Badinî',
    'ku_sorani': 'کوردی — سۆرانی',
  };
  static const _preview = <String, List<String>>{
    'en': ['Welcome', 'Dashboard', 'Orders', 'Settings'],
    'ar': ['مرحباً', 'لوحة التحكم', 'الطلبات', 'الإعدادات'],
    'ku_badini': ['Bi xêr hatî', 'Panela rêvebirinê', 'Ferman', 'Mîheng'],
    'ku_sorani': ['بەخێربێیت', 'داشبۆرد', 'داواکارییەکان', 'ڕێکخستنەکان'],
  };
  String _selected = 'en';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (!mounted) return;
    setState(() {
      _selected = _languages.containsKey(value) ? value! : 'en';
      _loading = false;
    });
  }

  Future<void> _save(String language) async {
    if (!_languages.containsKey(language)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language);
    if (!mounted) return;
    setState(() => _selected = language);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'Language preference saved on this device. Full app translation is not active yet.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final samples = _preview[_selected]!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dictionary & Language',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'Choose your preferred language. This screen previews translations; other app screens remain unchanged until localization is integrated.'),
        const SizedBox(height: 16),
        Card(
            child: RadioGroup<String>(
                groupValue: _selected,
                onChanged: (v) {
                  if (v != null) {
                    _save(v);
                  }
                },
                child: Column(children: [
                  for (final entry in _languages.entries)
                    RadioListTile<String>(
                      title: Text(entry.value),
                      value: entry.key,
                    ),
                ]))),
        const SizedBox(height: 16),
        Text('Translation preview',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: _selected == 'ar' || _selected == 'ku_sorani'
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              for (final sample in samples)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(sample,
                      textDirection:
                          _selected == 'ar' || _selected == 'ku_sorani'
                              ? TextDirection.rtl
                              : TextDirection.ltr),
                )
            ],
          ),
        )),
        const SizedBox(height: 12),
        const Text(
            'Next: connect localization to navigation, forms, validation messages, and backend-managed dictionary entries.'),
      ],
    );
  }
}
