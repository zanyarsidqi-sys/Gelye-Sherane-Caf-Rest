/// Pure, offline validation for credit-payment *drafts*.
/// This does not authorize a transaction or verify a Supabase account.
class CreditDraftValidation {
  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  static String? amountIqd(String? value) {
    final raw = (value ?? '').trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) {
      return 'Enter whole IQD amount';
    }
    final amount = int.tryParse(raw);
    if (amount == null || amount <= 0) {
      return 'Amount must be greater than zero';
    }
    return null;
  }

  static String effectiveMode(String source, String tableMode) =>
      source == 'Motel Order' ? 'Tourism' : tableMode;

  static String maskedBarcode(String barcode) {
    final value = barcode.trim();
    if (value.isEmpty) return '';
    if (value.length <= 4) return '*' * value.length;
    return '${'*' * (value.length - 4)}${value.substring(value.length - 4)}';
  }
}
