import 'dart:convert';

class PickupQrPayload {
  const PickupQrPayload({required this.orderId, required this.token});

  final String orderId;
  final String token;

  String encode() => jsonEncode({
    'type': 'mr_apache_pickup',
    'orderId': orderId,
    'token': token,
  });

  static PickupQrPayload decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'mr_apache_pickup' ||
        decoded['orderId'] is! String ||
        (decoded['orderId'] as String).isEmpty ||
        decoded['token'] is! String ||
        !RegExp(r'^[a-f0-9]{48}$').hasMatch(decoded['token'] as String)) {
      throw const FormatException('El QR no corresponde a un recojo válido.');
    }

    return PickupQrPayload(
      orderId: decoded['orderId'] as String,
      token: decoded['token'] as String,
    );
  }
}
