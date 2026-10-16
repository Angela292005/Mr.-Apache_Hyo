import 'package:flutter_test/flutter_test.dart';
import 'package:mr_apache_hyo/models/app_models.dart';
import 'package:mr_apache_hyo/providers/cart_provider.dart';
import 'package:mr_apache_hyo/utils/formatters.dart';

void main() {
  test(
    'el carrito calcula subtotales y cantidades y permite quitar productos',
    () {
      final cart = CartProvider();
      const pizza = Product(
        id: 'apache',
        name: 'A lo Apache',
        category: 'Pizzas',
        description: 'Pizza de la casa',
        image: '',
        available: true,
        prices: {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45},
      );

      cart.add(pizza, size: 'Personal');
      cart.add(pizza, size: 'Personal');

      expect(cart.itemCount, 2);
      expect(cart.subtotal, 27.2);

      final item = cart.items.single;
      cart.setQuantity(item, 1);
      expect(cart.subtotal, 13.6);

      cart.remove(item);
      expect(cart.items, isEmpty);
      expect(cart.subtotal, 0);
    },
  );

  test('normaliza nombres y valida apellidos con tildes y espacios', () {
    expect(normalizePersonName('  María   José  '), 'María José');
    expect(isValidPersonName('María José'), isTrue);
    expect(isValidPersonName('Muñoz Peña'), isTrue);
    expect(isValidPersonName('A'), isFalse);
    expect(isValidPersonName('Juan 2'), isFalse);
  });

  test('UserModel lee usuarios anteriores con campo name', () {
    final user = UserModel.fromMap({
      'name': 'María José Muñoz',
      'phone': '985555558',
      'email': 'maria@example.com',
      'role': 'cliente',
    }, id: 'uid');

    expect(user.nombres, 'María');
    expect(user.apellidos, 'José Muñoz');
    expect(user.nombreCompleto, 'María José Muñoz');
    expect(user.telefono, '985555558');
    expect(user.correo, 'maria@example.com');
  });
}
