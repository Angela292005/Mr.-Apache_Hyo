import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/app_models.dart';
import '../providers/cart_provider.dart';
import '../services/firebase_service.dart';
import '../utils/formatters.dart';
import '../utils/product_image_url.dart';
import '../widgets/product_image.dart';

class PizzaCustomizerScreen extends StatefulWidget {
  const PizzaCustomizerScreen({super.key, required this.onAdded});

  final VoidCallback onAdded;

  @override
  State<PizzaCustomizerScreen> createState() => _PizzaCustomizerScreenState();
}

class _PizzaCustomizerScreenState extends State<PizzaCustomizerScreen> {
  String? _size;
  String? _firstPizzaId;
  String? _secondPizzaId;
  String _dough = 'Fina tradicional';
  String _bakeLevel = 'Bien crocante';
  bool _stuffedCrust = false;
  bool _splitHalves = false;
  final Set<String> _toppings = {};

  static const _toppingPrices = <String, double>{
    'Queso Extra': 4,
    'Champiñones': 3.5,
    'Tocino Ahumado': 4.5,
    'Jamón': 3,
    'Aceitunas Negras': 2.5,
    'Pimientos Asados': 2.5,
  };
  late final Stream<List<Product>> _products = FirebaseService().products();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Product>>(
    stream: _products,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('No se pudo cargar la carta: ${snapshot.error}'),
        );
      }
      final pizzas = (snapshot.data ?? FirebaseService.defaultProducts)
          .where((product) => product.category == 'Pizzas' && product.available)
          .toList();
      if (pizzas.isEmpty) {
        return const Center(child: Text('No hay pizzas disponibles ahora.'));
      }
      final first = pizzas.firstWhere(
        (product) => product.id == _firstPizzaId,
        orElse: () => pizzas.first,
      );
      final selectedSize = first.prices.containsKey(_size)
          ? _size!
          : first.prices.keys.first;
      final second = pizzas.firstWhere(
        (product) => product.id == _secondPizzaId,
        orElse: () => pizzas.length > 1 ? pizzas[1] : pizzas.first,
      );
      final selectedPrice = _price(first, selectedSize);
      final halfPrice = _splitHalves
          ? math.max(selectedPrice, _price(second, selectedSize))
          : selectedPrice;
      final toppingsPrice = _toppings.fold<double>(
        0,
        (total, topping) => total + _toppingPrices[topping]!,
      );
      final total = halfPrice + toppingsPrice + (_stuffedCrust ? 6 : 0);

      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE7E2),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: AppTheme.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'HORNO ARTESANAL A 400°C',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.orange,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Icon(Icons.star, color: AppTheme.amber, size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Arma tu pizza a tu estilo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Elige tus ingredientes y disfruta el sabor Apache.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brown.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 16),
                _pizzaPreview(first, second, selectedSize, total),
                const SizedBox(height: 20),
                _sectionTitle('PASO 1', 'Selecciona el tamaño'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: first.prices.entries.map((entry) {
                    final selected = selectedSize == entry.key;
                    return ChoiceChip(
                      label: Text('${entry.key} · ${money(entry.value)}'),
                      selected: selected,
                      onSelected: (_) => setState(() => _size = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('PASO 2', 'Tipo de masa'),
                RadioGroup<String>(
                  groupValue: _dough,
                  onChanged: (value) => setState(() => _dough = value!),
                  child: Column(
                    children: ['Fina tradicional', 'Gruesa rústica']
                        .map(
                          (dough) => RadioListTile<String>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(dough),
                            subtitle: Text(
                              dough == 'Fina tradicional'
                                  ? 'A la piedra, ligera y crocante'
                                  : 'Esponjosa por dentro, crocante por fuera',
                            ),
                            value: dough,
                          ),
                        )
                        .toList(),
                  ),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Borde relleno de mozzarella'),
                  subtitle: const Text(
                    'Queso fundido en cada bocado · +S/ 6.00',
                  ),
                  value: _stuffedCrust,
                  onChanged: (value) => setState(() => _stuffedCrust = value),
                ),
                const SizedBox(height: 8),
                _sectionTitle('PASO 3', 'Elige tus sabores'),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dividir en dos mitades'),
                  subtitle: const Text('Combina dos pizzas en una.'),
                  value: _splitHalves,
                  onChanged: pizzas.length < 2
                      ? null
                      : (value) => setState(() => _splitHalves = value),
                ),
                _pizzaSelector(
                  label: _splitHalves ? 'Mitad A' : 'Sabor',
                  product: first,
                  pizzas: pizzas,
                ),
                if (_splitHalves)
                  _pizzaSelector(
                    label: 'Mitad B',
                    product: second,
                    pizzas: pizzas,
                  ),
                const SizedBox(height: 16),
                _sectionTitle('PASO 4', 'Toppings y extras'),
                ..._toppingPrices.entries.map(
                  (entry) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.key),
                    secondary: Text('+${money(entry.value)}'),
                    value: _toppings.contains(entry.key),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _toppings.add(entry.key);
                      } else {
                        _toppings.remove(entry.key);
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                _sectionTitle('PASO 5', 'Punto de horneado'),
                RadioGroup<String>(
                  groupValue: _bakeLevel,
                  onChanged: (value) => setState(() => _bakeLevel = value!),
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Dorado suave'),
                        subtitle: Text('Masa tierna y queso apenas fundido'),
                        value: 'Dorado suave',
                      ),
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('Bien crocante'),
                        subtitle: Text(
                          'Más tiempo al horno, textura crujiente',
                        ),
                        value: 'Bien crocante',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _addToCart(
                    first: first,
                    second: second,
                    size: selectedSize,
                    price: total,
                  ),
                  child: Text('Agregar · ${money(total)}'),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _pizzaPreview(
    Product first,
    Product second,
    String size,
    double total,
  ) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1EC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF2D8D0)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.local_pizza_outlined, color: AppTheme.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _splitHalves ? 'Mitad y mitad' : first.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                money(total),
                style: const TextStyle(
                  color: AppTheme.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 145,
                height: 145,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD17A),
                  border: Border.all(color: const Color(0xFFBE6D24), width: 8),
                ),
                child: ClipOval(
                  child: _splitHalves
                      ? Row(
                          children: [
                            Expanded(
                              child: ProductImage(
                                url: productImageUrl(first),
                                size: 72,
                              ),
                            ),
                            Expanded(
                              child: ProductImage(
                                url: productImageUrl(second),
                                size: 72,
                              ),
                            ),
                          ],
                        )
                      : ProductImage(url: productImageUrl(first), size: 135),
                ),
              ),
              if (_stuffedCrust)
                const Icon(
                  Icons.circle_outlined,
                  size: 142,
                  color: Colors.white,
                ),
            ],
          ),
        ),
        Text(
          _splitHalves ? '${first.name} + ${second.name}' : first.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _sectionTitle(String step, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFBE7E2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: AppTheme.red,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ],
    ),
  );

  Widget _pizzaSelector({
    required String label,
    required Product product,
    required List<Product> pizzas,
  }) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFFDAD3),
        child: Text(label == 'Mitad B' ? 'B' : 'A'),
      ),
      title: Text('$label: ${product.name}'),
      subtitle: Text(
        product.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.expand_more),
      onTap: () async {
        final selected = await showModalBottomSheet<Product>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: pizzas
                  .map(
                    (pizza) => ListTile(
                      title: Text(pizza.name),
                      subtitle: Text(pizza.description),
                      onTap: () => Navigator.pop(context, pizza),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
        if (selected != null) {
          setState(() {
            if (label == 'Mitad B') {
              _secondPizzaId = selected.id;
            } else {
              _firstPizzaId = selected.id;
            }
          });
        }
      },
    ),
  );

  double _price(Product product, String size) =>
      product.prices[size] ?? product.startingPrice;

  void _addToCart({
    required Product first,
    required Product second,
    required String size,
    required double price,
  }) {
    final name = _splitHalves
        ? 'Pizza mitad y mitad: ${first.name} / ${second.name}'
        : 'Pizza personalizada: ${first.name}';
    final notes = [
      'Masa: $_dough',
      'Horneado: $_bakeLevel',
      if (_stuffedCrust) 'Borde relleno de mozzarella',
      if (_splitHalves) 'Mitad A: ${first.name}; Mitad B: ${second.name}',
      if (_toppings.isNotEmpty) 'Extras: ${_toppings.join(', ')}',
    ].join(' · ');
    final product = Product(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      category: 'Pizzas',
      description: notes,
      image: productImageUrl(first),
      available: true,
      prices: {size: price},
    );
    context.read<CartProvider>().add(product, size: size, notes: notes);
    widget.onAdded();
  }
}
