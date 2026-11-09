import 'package:flutter_test/flutter_test.dart';
import 'package:mr_apache_hyo/models/app_models.dart';
import 'package:mr_apache_hyo/providers/cart_provider.dart';
import 'package:mr_apache_hyo/services/firebase_service.dart';
import 'package:mr_apache_hyo/utils/drive_image_url.dart';
import 'package:mr_apache_hyo/utils/formatters.dart';
import 'package:mr_apache_hyo/utils/product_image_url.dart';

void main() {
  test(
    'convierte enlaces compartidos de Google Drive para mostrar imágenes',
    () {
      expect(
        displayImageUrl(
          'https://drive.google.com/file/d/abc123/view?usp=sharing',
        ),
        'https://drive.google.com/uc?export=view&id=abc123',
      );
      expect(
        displayImageUrl('https://drive.google.com/open?id=abc123'),
        'https://drive.google.com/uc?export=view&id=abc123',
      );
      expect(
        displayImageUrl('https://example.com/pizza.jpg'),
        'https://example.com/pizza.jpg',
      );
      expect(
        validateImageUrl('enlace-inválido'),
        'Ingresa un enlace de imagen válido.',
      );
      expect(
        validateImageUrl('https://drive.google.com/file/d/abc123/view'),
        isNull,
      );
    },
  );

  test('la carta inicial incluye productos y precios por categoría', () {
    final products = FirebaseService.defaultProducts;
    final pizza = products.singleWhere(
      (product) => product.name == 'A lo Apache',
    );

    expect(products, hasLength(48));
    expect(products.map((product) => product.id).toSet(), hasLength(48));
    expect(pizza.category, 'Pizzas');
    expect(pizza.prices['Personal'], 13.6);
    expect(products.any((product) => product.category == 'Pastas'), isTrue);
    expect(products.every((product) => product.available), isTrue);
  });

  test('asigna fotos ilustrativas a platos sin foto propia', () {
    final products = FirebaseService.defaultProducts;
    final pizza = products.singleWhere(
      (product) => product.name == 'A lo Apache',
    );
    final drink = products.singleWhere(
      (product) => product.name == 'Gaseosa 1 L',
    );
    final garlicBread = products.singleWhere(
      (product) => product.name == 'Pan al ajo',
    );
    final pasta = products.singleWhere(
      (product) => product.name == 'Lasagna a la Bolognesa',
    );

    expect(productImageUrl(pizza), startsWith('https://'));
    expect(productImageUrl(drink), startsWith('https://'));
    expect(productImageUrl(garlicBread), startsWith('https://'));
    expect(productImageUrl(pasta), isEmpty);
    expect(
      productImageUrl(
        pizza,
        existingImage: 'https://drive.google.com/file/d/custom/view',
      ),
      'https://drive.google.com/uc?export=view&id=custom',
    );
  });

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
