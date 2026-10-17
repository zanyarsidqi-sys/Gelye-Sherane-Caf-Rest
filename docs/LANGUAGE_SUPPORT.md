# Interface languages

First use for customers and staff defaults to Kurdish Badini in Arabic script (`ku`). Arabic (`ar`) and English (`en`) are available from the language icon in customer/public and staff headers. A valid saved choice takes priority; an absent or invalid choice falls back to Badini. Preferences are saved on the current browser/device under `cafe.language.v1`, not synced between accounts/devices.

Arabic and Badini use RTL layout, English uses LTR. Switching does not reset navigation, order drafts or text fields. Preference storage failure must not prevent the app from opening or changing language for the current session.

Current dictionary: 201 shared interface labels and messages in each translation, including all 25 section names and key QR ordering/service/bill controls. English fallback remains for untranslated legacy cards, descriptions, dynamic errors, tooltips and some system date/time labels. This is not a claim of complete translation across all 727 catalog entries. Badini copy is a draft pending native-speaker review.

Product names, guest/customer names, notes, amounts, RPC names, database status codes and permission keys are not translated or rewritten in storage. Interface translation must remain separate from operational identifiers. Badini Material/Cupertino delegates cover common controls and fall back to base English text for unoverridden system strings.

Verification includes default/restored/invalid preference behavior, blocked storage, serialized rapid changes, RTL switching with retained input, actual app startup at phone width, and the existing workflow regression suite. See PR #16 for current check results. The implementation remains on the development branch until released.
