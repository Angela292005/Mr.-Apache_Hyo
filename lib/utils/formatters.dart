String money(num value) => 'S/ ${value.toStringAsFixed(2)}';

String normalizePersonName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

bool isValidPersonName(String value) {
  final normalized = normalizePersonName(value);
  return normalized.length >= 2 &&
      RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]+$').hasMatch(normalized);
}
