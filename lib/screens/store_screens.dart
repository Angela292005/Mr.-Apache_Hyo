import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import '../main.dart' show firebaseService;
import '../models/app_models.dart';
import '../providers/cart_provider.dart';
import '../utils/formatters.dart'
    show isValidPersonName, money, normalizePersonName;
import '../widgets/app_logo.dart';
import '../widgets/product_image.dart';

bool _validTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) return false;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  return hour < 24 && minute < 60;
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppTheme.red : AppTheme.brown,
    ),
  );
}

String authError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'email-already-in-use' => 'Ese correo ya tiene una cuenta.',
      'invalid-email' => 'El correo no tiene un formato válido.',
      'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
      'user-disabled' =>
        'Esta cuenta está deshabilitada. Contacta con el local.',
      'operation-not-allowed' =>
        'Este método de acceso no está habilitado en Firebase.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Correo o contraseña incorrectos.',
      'network-request-failed' => 'No hay conexión. Inténtalo nuevamente.',
      'too-many-requests' => 'Hubo demasiados intentos. Espera unos minutos antes de volver a probar.',
      _ => 'No se pudo completar la operación. Inténtalo nuevamente.',
    };
  }
  return 'Ocurrió un error: $error';
}

String? _validateProfileName(String? value, String label) {
  final normalized = normalizePersonName(value ?? '');
  if (normalized.length < 2) return 'Ingresa $label (mínimo 2 caracteres).';
  if (!isValidPersonName(normalized)) {
    return 'Usa solo letras, tildes, ñ y espacios.';
  }
  return null;
}

class StoreShell extends StatefulWidget {
  const StoreShell({super.key, required this.profile, required this.userId});
  final Map<String, dynamic> profile;
  final String userId;

  @override
  State<StoreShell> createState() => _StoreShellState();
}

class _StoreShellState extends State<StoreShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.profile['role'] == 'admin';
    final pages = [
      HomeScreen(onMenu: () => setState(() => _index = 1)),
      const MenuScreen(),
      const CartScreen(),
      OrdersScreen(isAdmin: isAdmin),
      ProfileScreen(profile: widget.profile, isAdmin: isAdmin),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AppLogo(size: 40),
            SizedBox(width: 10),
            Text('Mr. Apache', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          if (_index != 2)
            Consumer<CartProvider>(
              builder: (context, cart, _) => IconButton(
                tooltip: 'Carrito',
                onPressed: () => setState(() => _index = 2),
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text('${cart.itemCount}'),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pizza_outlined),
            label: 'Carta',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Carrito',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  bool _obscureConfirmation = true;

  String? _validatePersonName(String? value, String label) {
    final clean = normalizePersonName(value ?? '');
    if (clean.length < 2) return 'Ingresa $label (mínimo 2 caracteres).';
    if (!isValidPersonName(clean)) {
      return 'Usa solo letras, tildes, ñ y espacios.';
    }
    return null;
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_register) {
        await firebaseService.register(
          nombres: _nombres.text,
          apellidos: _apellidos.text,
          telefono: _phone.text,
          correo: _email.text,
          password: _password.text,
        );
      } else {
        await firebaseService.signIn(_email.text, _password.text);
      }
    } catch (error) {
      if (!mounted) return;
      showMessage(context, authError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      showMessage(
        context,
        'Escribe tu correo válido para recuperar la clave.',
        error: true,
      );
      return;
    }
    try {
      await firebaseService.sendPasswordReset(email);
      if (!mounted) return;
      showMessage(context, 'Enviamos un enlace de recuperación a $email.');
    } catch (error) {
      if (!mounted) return;
      showMessage(context, authError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: AppTheme.red,
        secondary: AppTheme.amber,
        surface: const Color(0xFF151518),
        onPrimary: Colors.white,
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFFE4E4E7),
      ),
      scaffoldBackgroundColor: const Color(0xFF09090B),
      textTheme: Theme.of(context).textTheme
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppTheme.amber),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF202024),
        labelStyle: const TextStyle(color: Color(0xFFE4E4E7)),
        floatingLabelStyle: const TextStyle(color: AppTheme.amber),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3F3F46)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3F3F46)),
        ),
      ),
    ),
    child: Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                color: const Color(0xFF151518),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppLogo(size: 144),
                        const SizedBox(height: 8),
                        const Text(
                          'Mr. Apache Pizzería',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'La favorita en Huancayo, un rinconcito en San Carlos',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFD4D4D8)),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _register ? 'Crea tu cuenta' : 'Bienvenido de vuelta',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.white),
                        ),
                        if (_register) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nombres,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nombres',
                            ),
                            validator: (value) =>
                                _validatePersonName(value, 'tus nombres'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _apellidos,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Apellidos',
                            ),
                            validator: (value) =>
                                _validatePersonName(value, 'tus apellidos'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Celular (9 dígitos)',
                            ),
                            validator: (value) =>
                                value == null ||
                                    !RegExp(r'^\d{9}$').hasMatch(value)
                                ? 'Ingresa un celular peruano de 9 dígitos.'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                          ),
                          validator: (value) =>
                              value == null ||
                                  !RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                                      .hasMatch(value.trim())
                              ? 'Ingresa un correo válido.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            suffixIcon: IconButton(
                              tooltip: _obscure
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'Mínimo 6 caracteres.'
                              : null,
                        ),
                        if (_register) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPassword,
                            obscureText: _obscureConfirmation,
                            decoration: InputDecoration(
                              labelText: 'Confirmar contraseña',
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmation
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                onPressed: () => setState(
                                  () => _obscureConfirmation =
                                      !_obscureConfirmation,
                                ),
                                icon: Icon(
                                  _obscureConfirmation
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            validator: (value) => value != _password.text
                                ? 'Las contraseñas no coinciden.'
                                : null,
                          ),
                        ],
                        if (!_register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _resetPassword,
                              child: const Text('Olvidé mi contraseña'),
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_register ? 'Crear cuenta' : 'Ingresar'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _register = !_register),
                          child: Text(
                            _register
                                ? 'Ya tengo una cuenta'
                                : 'Crear una cuenta nueva',
                          ),
                        ),
                        if (!_register)
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    try {
                                      await firebaseService.auth
                                          .signInAnonymously();
                                    } catch (error) {
                                      if (context.mounted) {
                                        showMessage(
                                          context,
                                          'No se pudo entrar como visitante. '
                                          'Habilita el método Anónimo en Firebase '
                                          'Authentication. ${authError(error)}',
                                          error: true,
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _busy = false);
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Explorar sin cuenta'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Branch>>(
    stream: firebaseService.branches(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('No se pudieron cargar los locales: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final branches = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [AppTheme.red, Color(0xFF8E1717)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Qué gusto verte!',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 8),
                Text(
                  'Pizza recién hecha,\npara compartir.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'La favorita en Huancayo, un rinconcito en San Carlos',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Elige tu local', style: Theme.of(context).textTheme.titleLarge),
          if (branches.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'El administrador debe cargar los locales iniciales.',
                ),
              ),
            )
          else
            Consumer<CartProvider>(
              builder: (context, cart, _) {
                final id = branches.any((b) => b.id == cart.selectedBranchId)
                    ? cart.selectedBranchId
                    : branches.first.id;
                return DropdownButtonFormField<String>(
                  initialValue: id,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal de recojo o delivery',
                  ),
                  items: branches
                      .map(
                        (branch) => DropdownMenuItem(
                          value: branch.id,
                          child: Text(
                            branch.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: cart.selectBranch,
                );
              },
            ),
          if (branches.isNotEmpty)
            Builder(
              builder: (context) {
                final cart = context.watch<CartProvider>();
                final branch = branches.firstWhere(
                  (item) => item.id == cart.selectedBranchId,
                  orElse: () => branches.first,
                );
                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.circle,
                      size: 14,
                      color: branch.isOpen ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      branch.isOpen ? 'Abierto ahora' : 'Cerrado por ahora',
                    ),
                    subtitle: Text(
                      'Atención: ${branch.openingTime}–${branch.closingTime}. '
                      'Almuerzo: lunes a viernes, ${branch.lunchOpeningTime}–'
                      '${branch.lunchClosingTime}.',
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onMenu,
            icon: const Icon(Icons.local_pizza),
            label: const Text('Pedir ahora'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompanyScreen()),
            ),
            icon: const Icon(Icons.place_outlined),
            label: const Text('Nosotros, horarios y contacto'),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firebaseService.promotions(),
            builder: (context, promotionsSnapshot) {
              if (promotionsSnapshot.hasError) {
                return Text(
                  'No se pudieron cargar promociones: ${promotionsSnapshot.error}',
                );
              }
              final promotions = promotionsSnapshot.data?.docs ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Promociones',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (promotions.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.local_offer_outlined,
                          color: AppTheme.red,
                        ),
                        title: Text('Combos desde S/ 19.00'),
                        subtitle: Text(
                          'Revisa la carta para conocer nuestros combos.',
                        ),
                      ),
                    ),
                  ...promotions.map((promotion) {
                    final data = promotion.data();
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.local_offer_outlined,
                          color: AppTheme.red,
                        ),
                        title: Text(data['name'] as String? ?? 'Promoción'),
                        subtitle: Text(
                          '${data['description'] ?? ''} · '
                          '${money((data['price'] as num?) ?? 0)}',
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          StreamBuilder<List<Product>>(
            stream: firebaseService.products(),
            builder: (context, products) {
              if (!products.hasData) return const SizedBox.shrink();
              final pizzas = products.data!
                  .where(
                    (product) =>
                        product.category == 'Pizzas' && product.available,
                  )
                  .take(3)
                  .toList();
              if (pizzas.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Pizzas para hoy',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...pizzas.map((product) => ProductTile(product: product)),
                ],
              );
            },
          ),
        ],
      );
    },
  );
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _search = TextEditingController();
  String _category = 'Todos';

  static const _categories = [
    'Todos',
    'Combos',
    'Pizzas',
    'Pastas',
    'Carnes y parrillas',
    'Bebidas',
    'Extras',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar en la carta',
          ),
        ),
      ),
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: _categories
              .map(
                (category) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      Expanded(
        child: StreamBuilder<List<Product>>(
          stream: firebaseService.products(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error al cargar la carta: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final query = _search.text.trim().toLowerCase();
            final products = snapshot.data!
                .where((item) => item.available)
                .where(
                  (item) => _category == 'Todos' || item.category == _category,
                )
                .where((item) => item.name.toLowerCase().contains(query))
                .toList();
            if (products.isEmpty) {
              return const Center(
                child: Text('No encontramos productos. Prueba otra búsqueda.'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              itemCount: products.length,
              itemBuilder: (context, index) =>
                  ProductTile(product: products[index]),
            );
          },
        ),
      ),
    ],
  );
}

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: ProductImage(url: product.image, size: 68),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${product.description}\nDesde ${money(product.startingPrice)}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: IconButton.filled(
        tooltip: 'Agregar al carrito',
        onPressed: () => _chooseProduct(context, product),
        icon: const Icon(Icons.add_shopping_cart),
      ),
      onTap: () => _chooseProduct(context, product),
    ),
  );
}

Future<void> _chooseProduct(BuildContext context, Product product) async {
  var size = product.prices.keys.first;
  final note = TextEditingController();
  final chosen = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product.description),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: size,
              decoration: const InputDecoration(labelText: 'Tamaño'),
              items: product.prices.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text('${entry.key} · ${money(entry.value)}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => refresh(() => size = value ?? size),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'Nota especial (opcional)',
                hintText: 'Ej. sin aceituna',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, size),
            child: const Text('Agregar'),
          ),
        ],
      ),
    ),
  );
  if (chosen != null && context.mounted) {
    context.read<CartProvider>().add(
      product,
      size: chosen,
      notes: note.text.trim(),
    );
    showMessage(context, '${product.name} agregado al carrito.');
  }
  note.dispose();
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) => Consumer<CartProvider>(
    builder: (context, cart, _) {
      if (cart.items.isEmpty) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 64, color: AppTheme.red),
              SizedBox(height: 12),
              Text('Tu carrito está vacío.'),
              Text('Explora la carta y agrega algo rico.'),
            ],
          ),
        );
      }
      return StreamBuilder<List<Branch>>(
        stream: firebaseService.branches(),
        builder: (context, branchSnapshot) {
          final branches = branchSnapshot.data ?? const <Branch>[];
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (branchSnapshot.hasError)
                      Text('Error al obtener locales: ${branchSnapshot.error}'),
                    ...cart.items.map(
                      (item) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ProductImage(url: item.product.image, size: 62),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${item.size} · ${money(item.unitPrice)}',
                                    ),
                                    if (item.notes.isNotEmpty)
                                      Text('Nota: ${item.notes}'),
                                    Row(
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => cart.setQuantity(
                                            item,
                                            item.quantity - 1,
                                          ),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Text('${item.quantity}'),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => cart.setQuantity(
                                            item,
                                            item.quantity + 1,
                                          ),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          money(item.subtotal),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Quitar del carrito',
                                onPressed: () => cart.remove(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _confirmAction(
                          context,
                          '¿Vaciar carrito?',
                          'Se quitarán todos los productos.',
                          () async => cart.clear(),
                        ),
                        child: const Text('Vaciar carrito'),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text(
                            money(cart.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: branches.isEmpty
                            ? null
                            : () => _openCheckout(context, branches),
                        child: const Text('Continuar con el pedido'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _openCheckout(BuildContext context, List<Branch> branches) async {
  final cart = context.read<CartProvider>();
  if (firebaseService.currentUser?.isAnonymous == true) {
    await firebaseService.signOut();
    if (context.mounted) {
      showMessage(
        context,
        'Ingresa o crea una cuenta para confirmar tu pedido.',
      );
    }
    return;
  }
  final form = GlobalKey<FormState>();
  final address = TextEditingController();
  final notes = TextEditingController();
  var type = 'Delivery';
  var payment = 'Efectivo';
  var selectedBranchId =
      branches.any((branch) => branch.id == cart.selectedBranchId)
      ? cart.selectedBranchId!
      : branches.first.id;
  var busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) {
        final branch = branches.firstWhere(
          (item) => item.id == selectedBranchId,
        );
        final fee = cart.subtotal >= 50 ? 0.0 : 3.0;
        return AlertDialog(
          title: const Text('Confirma tu pedido'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: const InputDecoration(labelText: 'Sucursal'),
                    items: branches
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => refresh(
                      () => selectedBranchId = value ?? selectedBranchId,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de pedido',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Delivery',
                        child: Text('Delivery'),
                      ),
                      DropdownMenuItem(
                        value: 'Recojo en tienda',
                        child: Text('Recojo en tienda'),
                      ),
                    ],
                    onChanged: (value) => refresh(() => type = value ?? type),
                  ),
                  if (type == 'Delivery') ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: address,
                      decoration: const InputDecoration(
                        labelText: 'Dirección de entrega',
                      ),
                      validator: (value) =>
                          type == 'Delivery' &&
                              (value == null || value.trim().length < 6)
                          ? 'Indica una dirección completa.'
                          : null,
                    ),
                    if (!branch.acceptsDelivery)
                      const Text(
                        'Esta sucursal no acepta delivery.',
                        style: TextStyle(color: AppTheme.red),
                      ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    decoration: const InputDecoration(
                      labelText: 'Método de pago',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Efectivo',
                        child: Text('Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'Yape/Plin',
                        child: Text('Yape / Plin'),
                      ),
                      DropdownMenuItem(
                        value: 'Tarjeta Visa',
                        child: Text('Tarjeta Visa (al recibir)'),
                      ),
                    ],
                    onChanged: (value) =>
                        refresh(() => payment = value ?? payment),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notes,
                    decoration: const InputDecoration(
                      labelText: 'Notas del pedido (opcional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Envío: ${money(fee)}${fee == 0 ? ' (gratis desde S/ 50.00)' : ''}\n'
                    'Total: ${money(cart.subtotal + fee)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      if (!branch.isOpen) {
                        showMessage(
                          context,
                          'La sucursal está cerrada. Solo aceptamos pedidos durante su horario.',
                          error: true,
                        );
                        return;
                      }
                      if (type == 'Delivery' && !branch.acceptsDelivery) {
                        showMessage(
                          context,
                          'Esta sucursal no acepta delivery.',
                          error: true,
                        );
                        return;
                      }
                      refresh(() => busy = true);
                      try {
                        await firebaseService.submitOrder(
                          items: cart.items,
                          branch: branch,
                          deliveryType: type,
                          address: type == 'Delivery'
                              ? address.text.trim()
                              : '',
                          payment: payment,
                          notes: notes.text.trim(),
                          deliveryFee: fee,
                        );
                        cart.clear();
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          showMessage(
                            context,
                            '¡Pedido registrado! Lo verás en Mis pedidos.',
                          );
                        }
                      } catch (error) {
                        refresh(() => busy = false);
                        if (context.mounted) {
                          showMessage(
                            context,
                            'No se pudo guardar el pedido: $error',
                            error: true,
                          );
                        }
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar pedido'),
            ),
          ],
        );
      },
    ),
  );
  address.dispose();
  notes.dispose();
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<OrderRecord>>(
    stream: firebaseService.orders(admin: isAdmin),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('No se pudieron cargar pedidos: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final orders = snapshot.data!;
      if (orders.isEmpty) {
        return const Center(child: Text('Todavía no tienes pedidos.'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) =>
            OrderTile(order: orders[index], isAdmin: isAdmin),
      );
    },
  );
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.isAdmin});
  final OrderRecord order;
  final bool isAdmin;

  static const _statuses = [
    'Pendiente',
    'Confirmado',
    'En preparación',
    'En camino',
    'Listo para recoger',
    'Entregado',
    'Cancelado',
  ];

  @override
  Widget build(BuildContext context) {
    final stamp = order.createdAt == null
        ? 'Enviando fecha…'
        : DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt!);
    return Card(
      child: ExpansionTile(
        title: Text(
          'Pedido ${order.number}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${order.status} · ${money(order.total)} · $stamp'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${order.branchName} · ${order.deliveryType}'),
          ),
          if (order.customerName.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Cliente: ${order.customerName}'),
            ),
          if (order.customerPhone.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Teléfono: ${order.customerPhone}'),
            ),
          if (order.address.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Dirección: ${order.address}'),
            ),
          const SizedBox(height: 8),
          ...order.items.map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${item['quantity']} × ${item['name']} (${item['size']})  '
                '${money((item['subtotal'] as num?) ?? 0)}',
              ),
            ),
          ),
          const Divider(),
          if (order.status != 'Cancelado')
            Wrap(
              spacing: 4,
              children: _statuses
                  .where(
                    (status) =>
                        status == 'Pendiente' ||
                        status == 'Confirmado' ||
                        status == 'En preparación' ||
                        status ==
                            (order.deliveryType == 'Delivery'
                                ? 'En camino'
                                : 'Listo para recoger') ||
                        status == 'Entregado' ||
                        status == 'Cancelado',
                  )
                  .map((status) {
                    final done =
                        _statuses.indexOf(status) <=
                        _statuses.indexOf(order.status);
                    return Chip(
                      avatar: Icon(
                        done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: done ? Colors.green : Colors.grey,
                      ),
                      label: Text(status, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    );
                  })
                  .toList(),
            ),
          if (isAdmin)
            DropdownButtonFormField<String>(
              initialValue: order.status,
              decoration: const InputDecoration(labelText: 'Cambiar estado'),
              items: _statuses
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (status) async {
                if (status == null) return;
                try {
                  await firebaseService.setOrderStatus(order.id, status);
                } catch (error) {
                  if (context.mounted) {
                    showMessage(context, 'Error: $error', error: true);
                  }
                }
              },
            )
          else if (order.status == 'Pendiente')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmAction(
                  context,
                  '¿Cancelar pedido?',
                  'Solo se puede cancelar mientras esté pendiente.',
                  () async {
                    try {
                      await firebaseService.cancelOrder(order.id);
                      if (context.mounted) {
                        showMessage(context, 'Pedido cancelado.');
                      }
                    } catch (error) {
                      if (context.mounted) {
                        showMessage(context, 'Error: $error', error: true);
                      }
                    }
                  },
                ),
                child: const Text('Cancelar pedido'),
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Inversiones Cesarvero S.A.C. · RUC 20612033111',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('Ver comprobante'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text('Comprobante · ${order.number}'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pizzería-Restaurant Mr. Apache'),
                        const Text('Inversiones Cesarvero S.A.C.'),
                        const Text('RUC 20612033111'),
                        const Divider(),
                        if (order.customerName.isNotEmpty)
                          Text('Cliente: ${order.customerName}'),
                        Text('Sucursal: ${order.branchName}'),
                        Text('Pedido: ${order.deliveryType}'),
                        if (order.address.isNotEmpty)
                          Text('Dirección: ${order.address}'),
                        const Divider(),
                        ...order.items.map(
                          (item) => Text(
                            '${item['quantity']} × ${item['name']} '
                            '(${item['size']}) — '
                            '${money((item['subtotal'] as num?) ?? 0)}',
                          ),
                        ),
                        const Divider(),
                        Text(
                          'Total: ${money(order.total)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.isAdmin,
  });
  final Map<String, dynamic> profile;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final user = UserModel.fromMap(profile);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: AppTheme.red,
          child: Text(
            user.nombres.isEmpty ? 'M' : user.nombres[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user.nombreCompleto.isEmpty ? 'Cliente' : user.nombreCompleto,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(user.correo, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              if (profile['role'] != 'visitante') ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar perfil'),
                  subtitle: Text(user.telefono),
                  onTap: () => _editProfile(context, profile),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Mis direcciones'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.star_outline),
                  title: const Text('Mis reseñas'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewsScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('Reservas de mesa'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReservationsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
              ] else
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Modo visitante'),
                  subtitle: Text(
                    'Ingresa o regístrate para hacer pedidos y guardar tus datos.',
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Nosotros / Contacto'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CompanyScreen()),
                ),
              ),
              if (isAdmin) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Panel de administrador'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _confirmAction(
            context,
            '¿Cerrar sesión?',
            'Tendrás que ingresar nuevamente para hacer pedidos.',
            firebaseService.signOut,
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

Future<void> _editProfile(
  BuildContext context,
  Map<String, dynamic> profile,
) async {
  final form = GlobalKey<FormState>();
  final currentUser = UserModel.fromMap(profile);
  final nombres = TextEditingController(text: currentUser.nombres);
  final apellidos = TextEditingController(text: currentUser.apellidos);
  final phone = TextEditingController(text: currentUser.telefono);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Editar perfil'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nombres,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombres'),
              validator: (value) => _validateProfileName(value, 'tus nombres'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: apellidos,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Apellidos'),
              validator: (value) =>
                  _validateProfileName(value, 'tus apellidos'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular (9 dígitos)',
              ),
              validator: (value) =>
                  value == null || !RegExp(r'^\d{9}$').hasMatch(value)
                  ? 'Ingresa un celular válido.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            if (!form.currentState!.validate()) return;
            try {
              await firebaseService.updateProfile(
                nombres: nombres.text,
                apellidos: apellidos.text,
                telefono: phone.text,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (error) {
              if (dialogContext.mounted) {
                showMessage(dialogContext, 'Error: $error', error: true);
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  nombres.dispose();
  apellidos.dispose();
  phone.dispose();
  if (saved == true && context.mounted) {
    showMessage(context, 'Perfil actualizado.');
  }
}

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis direcciones')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _editAddress(context),
      icon: const Icon(Icons.add),
      label: const Text('Agregar'),
    ),
    body: StreamBuilder(
      stream: firebaseService.addresses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final addresses = snapshot.data!.docs;
        if (addresses.isEmpty) {
          return const Center(child: Text('Aún no guardas direcciones.'));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: addresses.map((doc) {
            final data = doc.data();
            return Card(
              child: ListTile(
                leading: Icon(
                  data['primary'] == true
                      ? Icons.star
                      : Icons.location_on_outlined,
                  color: AppTheme.red,
                ),
                title: Text(data['name'] as String? ?? 'Dirección'),
                subtitle: Text(data['address'] as String? ?? ''),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editAddress(context, id: doc.id, values: data);
                    } else if (action == 'delete') {
                      await _confirmAction(
                        context,
                        '¿Eliminar dirección?',
                        data['address'] as String? ?? '',
                        () => firebaseService.deleteDocument(
                          'users/${firebaseService.currentUser!.uid}/addresses',
                          doc.id,
                        ),
                      );
                    } else {
                      try {
                        await firebaseService.saveAddress(doc.id, {
                          ...data,
                          'primary': true,
                        });
                      } catch (error) {
                        if (context.mounted) {
                          showMessage(context, 'Error: $error', error: true);
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'primary',
                      child: Text('Marcar principal'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

Future<void> _editAddress(
  BuildContext context, {
  String? id,
  Map<String, dynamic>? values,
}) async {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: values?['name'] as String? ?? '');
  final address = TextEditingController(
    text: values?['address'] as String? ?? '',
  );
  var primary = values?['primary'] as bool? ?? false;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(id == null ? 'Nueva dirección' : 'Editar dirección'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Nombre (Casa, trabajo...)',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe un nombre.'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: address,
                decoration: const InputDecoration(
                  labelText: 'Dirección completa',
                ),
                validator: (value) => value == null || value.trim().length < 6
                    ? 'Completa la dirección.'
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: primary,
                title: const Text('Dirección principal'),
                onChanged: (value) => refresh(() => primary = value ?? false),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await firebaseService.saveAddress(id, {
                  'name': name.text.trim(),
                  'address': address.text.trim(),
                  'primary': primary,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  showMessage(dialogContext, 'Error: $error', error: true);
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  address.dispose();
  if (saved == true && context.mounted) {
    showMessage(context, 'Dirección guardada.');
  }
}

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mis reseñas')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _editReview(context),
      icon: const Icon(Icons.rate_review_outlined),
      label: const Text('Escribir reseña'),
    ),
    body: StreamBuilder(
      stream: firebaseService.reviews(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snapshot.data!.docs;
        if (reviews.isEmpty) {
          return const Center(child: Text('Aún no tienes reseñas.'));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: reviews.map((doc) {
            final data = doc.data();
            return Card(
              child: ListTile(
                leading: Text('${data['stars'] ?? 0} ★'),
                title: Text(data['comment'] as String? ?? ''),
                subtitle:
                    data['customerName'] is String &&
                        (data['customerName'] as String).isNotEmpty
                    ? Text('De ${data['customerName']}')
                    : null,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editReview(context, id: doc.id, values: data);
                    } else {
                      await _confirmAction(
                        context,
                        '¿Eliminar reseña?',
                        'No se puede deshacer esta acción.',
                        () => firebaseService.deleteDocument('reviews', doc.id),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

Future<void> _editReview(
  BuildContext context, {
  String? id,
  Map<String, dynamic>? values,
}) async {
  final form = GlobalKey<FormState>();
  final comment = TextEditingController(
    text: values?['comment'] as String? ?? '',
  );
  var stars = values?['stars'] as int? ?? 5;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(id == null ? 'Tu reseña' : 'Editar reseña'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: stars,
                decoration: const InputDecoration(labelText: 'Calificación'),
                items: [1, 2, 3, 4, 5]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          '$value ${value == 1 ? 'estrella' : 'estrellas'}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => refresh(() => stars = value ?? stars),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: comment,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Comentario'),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'Escribe un comentario.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await firebaseService.saveReview(
                  id: id,
                  stars: stars,
                  comment: comment.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  showMessage(dialogContext, 'Error: $error', error: true);
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  comment.dispose();
  if (saved == true && context.mounted) {
    showMessage(context, 'Reseña guardada.');
  }
}

class ReservationsScreen extends StatelessWidget {
  const ReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reservas de mesa')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _editReservation(context),
      icon: const Icon(Icons.add),
      label: const Text('Reservar'),
    ),
    body: StreamBuilder(
      stream: firebaseService.reservations(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reservations = snapshot.data!.docs.toList()
          ..sort((first, second) {
            final firstDate =
                (first.data()['date'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final secondDate =
                (second.data()['date'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return firstDate.compareTo(secondDate);
          });
        if (reservations.isEmpty) {
          return const Center(child: Text('Aún no tienes reservas.'));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: reservations.map((doc) {
            final data = doc.data();
            final date = (data['date'] as Timestamp?)?.toDate();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.event, color: AppTheme.red),
                title: Text('${data['branchName']} · ${data['status']}'),
                subtitle: Text(
                  '${date == null ? '' : DateFormat('dd/MM/yyyy').format(date)} '
                  'a las ${data['time']} · ${data['people']} personas',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editReservation(context, id: doc.id, values: data);
                    } else if (action == 'cancel') {
                      try {
                        await doc.reference.update({'status': 'Cancelada'});
                        if (context.mounted) {
                          showMessage(context, 'Reserva cancelada.');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          showMessage(context, 'Error: $error', error: true);
                        }
                      }
                    } else {
                      await _confirmAction(
                        context,
                        '¿Eliminar reserva?',
                        'Se borrará esta reserva.',
                        () => firebaseService.deleteDocument(
                          'reservations',
                          doc.id,
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'cancel', child: Text('Cancelar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

Future<void> _editReservation(
  BuildContext context, {
  String? id,
  Map<String, dynamic>? values,
}) async {
  final branchSnapshot = await firebaseService.firestore
      .collection('branches')
      .get();
  if (!context.mounted) return;
  if (branchSnapshot.docs.isEmpty) {
    if (context.mounted) {
      showMessage(context, 'No hay sucursales disponibles.', error: true);
    }
    return;
  }
  final branches = branchSnapshot.docs.map(Branch.fromDoc).toList();
  final timestamp = values?['date'] as Timestamp?;
  var date = timestamp?.toDate() ?? DateTime.now().add(const Duration(days: 1));
  var time = values?['time'] as String? ?? '19:00';
  var people = values?['people'] as int? ?? 2;
  var branchId = values?['branchId'] as String? ?? branches.first.id;
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(id == null ? 'Nueva reserva' : 'Editar reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: Text(DateFormat('dd/MM/yyyy').format(date)),
              onTap: () async {
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: date.isBefore(DateTime.now())
                      ? DateTime.now()
                      : date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                );
                if (chosen != null && context.mounted) {
                  refresh(() => date = chosen);
                }
              },
            ),
            TextFormField(
              initialValue: time,
              decoration: const InputDecoration(labelText: 'Hora (ej. 19:00)'),
              onChanged: (value) => time = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: '$people',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Número de personas',
              ),
              onChanged: (value) => people = int.tryParse(value) ?? 0,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: branchId,
              decoration: const InputDecoration(labelText: 'Sucursal'),
              items: branches
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => refresh(() => branchId = value ?? branchId),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final parsedTime = _validTime(time);
              if (!parsedTime || people < 1 || people > 30) {
                showMessage(
                  context,
                  'Revisa la hora y el número de personas.',
                  error: true,
                );
                return;
              }
              try {
                await firebaseService.saveReservation(
                  id: id,
                  date: date,
                  time: time,
                  people: people,
                  branch: branches.firstWhere(
                    (branch) => branch.id == branchId,
                  ),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  showMessage(dialogContext, 'Error: $error', error: true);
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  if (saved == true && context.mounted) {
    showMessage(context, 'Reserva guardada.');
  }
}

Future<void> _confirmAction(
  BuildContext context,
  String title,
  String detail,
  Future<void> Function() action,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(detail),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        showMessage(context, 'No se pudo completar: $error', error: true);
      }
    }
  }
}

class CompanyScreen extends StatelessWidget {
  const CompanyScreen({super.key});

  Future<void> _open(Uri uri, BuildContext context) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      showMessage(context, 'No se pudo abrir el enlace.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nosotros / Contacto')),
    body: StreamBuilder<List<Branch>>(
      stream: firebaseService.branches(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final branches = snapshot.data ?? const <Branch>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: AppLogo(size: 180)),
            const SizedBox(height: 12),
            const Text(
              'Pizzería-Restaurant Mr. Apache',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Somos un restaurante familiar y acogedor. Preparamos pizzas, pastas, '
              'pollos, parrilladas, sándwiches, aperitivos, calientitos y vinos al momento, '
              'con insumos frescos y de buena calidad. Nos recomiendan por el sabor, '
              'el buen precio, la atención rápida y el ambiente tranquilo.',
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.schedule),
                title: Text('Horario de atención'),
                subtitle: Text(
                  'Todos los días 16:00–00:00\n'
                  'Almuerzo: lunes a viernes 12:30–14:30\n'
                  'Los pedidos en línea se aceptan durante el horario de cada local.',
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            ...branches.map(
              (branch) => Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront, color: AppTheme.red),
                  title: Text(branch.name),
                  subtitle: Text(branch.address),
                  trailing: IconButton(
                    tooltip: 'Cómo llegar',
                    icon: const Icon(Icons.directions),
                    onPressed: () => _open(
                      Uri.https('www.google.com', '/maps/search/', {
                        'api': '1',
                        'query': branch.address,
                      }),
                      context,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  _open(Uri(scheme: 'tel', path: '+51985595558'), context),
              icon: const Icon(Icons.call),
              label: const Text('Llamar: +51 985 595 558'),
            ),
            OutlinedButton.icon(
              onPressed: () => _open(
                Uri.https('wa.me', '/51985595558', {
                  'text': 'Hola, Mr. Apache. Quisiera hacer una consulta.',
                }),
                context,
              ),
              icon: const Icon(Icons.chat),
              label: const Text('Escribir por WhatsApp'),
            ),
            TextButton.icon(
              onPressed: () =>
                  _open(Uri.https('pizzeriamrapache.com'), context),
              icon: const Icon(Icons.language),
              label: const Text('pizzeriamrapache.com'),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long),
                title: Text('Inversiones Cesarvero S.A.C.'),
                subtitle: Text('RUC 20612033111'),
              ),
            ),
            const Text(
              'Aceptamos Visa. Reserva tu mesa y encuentra también nuestro delivery en Rappi.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    ),
  );
}

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Productos', icon: Icon(Icons.local_pizza_outlined)),
            Tab(text: 'Sucursales', icon: Icon(Icons.store_outlined)),
            Tab(text: 'Promos', icon: Icon(Icons.local_offer_outlined)),
            Tab(text: 'Pedidos', icon: Icon(Icons.receipt_long_outlined)),
          ],
        ),
      ),
      body: const TabBarView(
        children: [
          _AdminProducts(),
          _AdminBranches(),
          _AdminPromotions(),
          _AdminOrders(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            await firebaseService.seedInitialData();
            if (context.mounted) {
              showMessage(context, 'Carta y sucursales iniciales cargadas.');
            }
          } catch (error) {
            if (context.mounted) {
              showMessage(
                context,
                'No se pudieron cargar los datos: $error',
                error: true,
              );
            }
          }
        },
        icon: const Icon(Icons.cloud_upload_outlined),
        label: const Text('Cargar datos iniciales'),
      ),
    ),
  );
}

class _AdminProducts extends StatelessWidget {
  const _AdminProducts();

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      heroTag: 'addProduct',
      onPressed: () => _editProduct(context),
      child: const Icon(Icons.add),
    ),
    body: StreamBuilder<List<Product>>(
      stream: firebaseService.products(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Text('Aún no hay productos. Carga la carta inicial.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: snapshot.data!.map((product) {
            return Card(
              child: ListTile(
                leading: Icon(
                  product.available ? Icons.check_circle : Icons.pause_circle,
                  color: product.available ? Colors.green : Colors.grey,
                ),
                title: Text(product.name),
                subtitle: Text(
                  '${product.category} · Desde ${money(product.startingPrice)}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editProduct(context, product: product);
                    } else if (action == 'toggle') {
                      try {
                        await firebaseService.saveProduct(product.id, {
                          'available': !product.available,
                        });
                      } catch (error) {
                        if (context.mounted) {
                          showMessage(context, 'Error: $error', error: true);
                        }
                      }
                    } else {
                      await _confirmAction(
                        context,
                        '¿Eliminar producto?',
                        product.name,
                        () => firebaseService.deleteDocument(
                          'products',
                          product.id,
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(product.available ? 'Desactivar' : 'Activar'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

Future<void> _editProduct(BuildContext context, {Product? product}) async {
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _ProductForm(product: product),
  );
  if (result == null) return;
  try {
    await firebaseService.saveProduct(product?.id, result);
    if (context.mounted) showMessage(context, 'Producto guardado.');
  } catch (error) {
    if (context.mounted) {
      showMessage(context, 'No se pudo guardar: $error', error: true);
    }
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.product});
  final Product? product;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _description = TextEditingController(
    text: widget.product?.description ?? '',
  );
  late final _image = TextEditingController(text: widget.product?.image ?? '');
  late final _personal = TextEditingController(
    text: widget.product?.prices['Personal']?.toString() ?? '',
  );
  late final _medium = TextEditingController(
    text: widget.product?.prices['Mediana']?.toString() ?? '',
  );
  late final _family = TextEditingController(
    text: widget.product?.prices['Familiar']?.toString() ?? '',
  );
  late final _single = TextEditingController(
    text:
        widget.product?.prices['Único']?.toString() ??
        widget.product?.startingPrice.toString() ??
        '',
  );
  late String _category = widget.product?.category ?? 'Combos';
  bool _available = true;

  @override
  void initState() {
    super.initState();
    _available = widget.product?.available ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    _personal.dispose();
    _medium.dispose();
    _family.dispose();
    _single.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'Nuevo producto' : 'Editar producto'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Campo obligatorio.'
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items:
                    const [
                          'Combos',
                          'Pizzas',
                          'Pastas',
                          'Carnes y parrillas',
                          'Bebidas',
                          'Extras',
                        ]
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(),
                onChanged: (value) =>
                    setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción / ingredientes',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Campo obligatorio.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'URL de imagen (opcional)',
                ),
              ),
              const SizedBox(height: 8),
              if (_category == 'Pizzas') ...[
                _priceField(_personal, 'Personal (S/)'),
                _priceField(_medium, 'Mediana (S/)'),
                _priceField(_family, 'Familiar (S/)'),
              ] else
                _priceField(_single, 'Precio (S/)'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible'),
                value: _available,
                onChanged: (value) => setState(() => _available = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final prices = <String, double>{};
          if (_category == 'Pizzas') {
            for (final entry in {
              'Personal': _personal,
              'Mediana': _medium,
              'Familiar': _family,
            }.entries) {
              final value = double.tryParse(entry.value.text);
              if (value == null || value <= 0) {
                showMessage(
                  context,
                  'Ingresa precios mayores a cero para los tres tamaños.',
                );
                return;
              }
              prices[entry.key] = value;
            }
          } else {
            final value = double.tryParse(_single.text);
            if (value == null || value <= 0) {
              showMessage(context, 'Ingresa un precio mayor a cero.');
              return;
            }
            prices['Único'] = value;
          }
          Navigator.pop(context, {
            'name': _name.text.trim(),
            'category': _category,
            'description': _description.text.trim(),
            'image': _image.text.trim(),
            'available': _available,
            'prices': prices,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
        child: const Text('Guardar'),
      ),
    ],
  );

  Widget _priceField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) => double.tryParse(value ?? '') == null
          ? 'Ingresa un precio numérico.'
          : null,
    ),
  );
}

class _AdminBranches extends StatelessWidget {
  const _AdminBranches();

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      heroTag: 'addBranch',
      onPressed: () => _editBranch(context),
      child: const Icon(Icons.add),
    ),
    body: StreamBuilder<List<Branch>>(
      stream: firebaseService.branches(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: snapshot.data!.map((branch) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.storefront, color: AppTheme.red),
                title: Text(branch.name),
                subtitle: Text(
                  '${branch.address}\n'
                  '${branch.openingTime}–${branch.closingTime} · '
                  'almuerzo L–V ${branch.lunchOpeningTime}–${branch.lunchClosingTime}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editBranch(context, branch: branch);
                    } else {
                      await _confirmAction(
                        context,
                        '¿Eliminar sucursal?',
                        branch.name,
                        () => firebaseService.deleteDocument(
                          'branches',
                          branch.id,
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

Future<void> _editBranch(BuildContext context, {Branch? branch}) async {
  final name = TextEditingController(text: branch?.name ?? '');
  final address = TextEditingController(text: branch?.address ?? '');
  final phone = TextEditingController(text: branch?.phone ?? '+51 985 595 558');
  final opens = TextEditingController(text: branch?.openingTime ?? '16:00');
  final closes = TextEditingController(text: branch?.closingTime ?? '00:00');
  final lunchOpens = TextEditingController(
    text: branch?.lunchOpeningTime ?? '12:30',
  );
  final lunchCloses = TextEditingController(
    text: branch?.lunchClosingTime ?? '14:30',
  );
  var delivery = branch?.acceptsDelivery ?? true;
  final form = GlobalKey<FormState>();
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(branch == null ? 'Nueva sucursal' : 'Editar sucursal'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _requiredField(name, 'Nombre del local'),
                _requiredField(address, 'Dirección'),
                _requiredField(phone, 'Teléfono'),
                _requiredField(opens, 'Apertura (HH:mm)'),
                _requiredField(closes, 'Cierre (HH:mm)'),
                _requiredField(lunchOpens, 'Almuerzo desde (HH:mm)'),
                _requiredField(lunchCloses, 'Almuerzo hasta (HH:mm)'),
                SwitchListTile(
                  title: const Text('Acepta delivery'),
                  value: delivery,
                  onChanged: (value) => refresh(() => delivery = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              if (!_validTime(opens.text) ||
                  !_validTime(closes.text) ||
                  !_validTime(lunchOpens.text) ||
                  !_validTime(lunchCloses.text)) {
                showMessage(context, 'Usa formato de hora HH:mm.', error: true);
                return;
              }
              Navigator.pop(dialogContext, {
                'name': name.text.trim(),
                'address': address.text.trim(),
                'phone': phone.text.trim(),
                'openingTime': opens.text,
                'closingTime': closes.text,
                'lunchOpeningTime': lunchOpens.text,
                'lunchClosingTime': lunchCloses.text,
                'acceptsDelivery': delivery,
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  address.dispose();
  phone.dispose();
  opens.dispose();
  closes.dispose();
  lunchOpens.dispose();
  lunchCloses.dispose();
  if (result == null) return;
  try {
    await firebaseService.saveBranch(branch?.id, result);
    if (context.mounted) showMessage(context, 'Sucursal guardada.');
  } catch (error) {
    if (context.mounted) showMessage(context, 'Error: $error', error: true);
  }
}

Widget _requiredField(TextEditingController controller, String label) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Campo obligatorio.' : null,
      ),
    );

class _AdminPromotions extends StatelessWidget {
  const _AdminPromotions();

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      heroTag: 'addPromotion',
      onPressed: () => _editPromotion(context),
      child: const Icon(Icons.add),
    ),
    body: StreamBuilder(
      stream: firebaseService.promotions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final promotions = snapshot.data!.docs;
        if (promotions.isEmpty) {
          return const Center(child: Text('No hay promociones todavía.'));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: promotions.map((doc) {
            final data = doc.data();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.local_offer, color: AppTheme.red),
                title: Text(data['name'] as String? ?? ''),
                subtitle: Text(
                  '${data['description'] ?? ''} · ${money((data['price'] as num?) ?? 0)}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editPromotion(context, id: doc.id, values: data);
                    } else {
                      await _confirmAction(
                        context,
                        '¿Eliminar promoción?',
                        data['name'] as String? ?? '',
                        () => firebaseService.deleteDocument(
                          'promotions',
                          doc.id,
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

Future<void> _editPromotion(
  BuildContext context, {
  String? id,
  Map<String, dynamic>? values,
}) async {
  final name = TextEditingController(text: values?['name'] as String? ?? '');
  final description = TextEditingController(
    text: values?['description'] as String? ?? '',
  );
  final price = TextEditingController(text: values?['price']?.toString() ?? '');
  final image = TextEditingController(text: values?['image'] as String? ?? '');
  final form = GlobalKey<FormState>();
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(id == null ? 'Nueva promoción / combo' : 'Editar promoción'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _requiredField(name, 'Nombre'),
            _requiredField(description, 'Descripción'),
            TextFormField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Precio (S/)'),
              validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                  ? 'Ingresa un precio mayor a cero.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: image,
              decoration: const InputDecoration(
                labelText: 'URL de imagen (opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(dialogContext, {
              'name': name.text.trim(),
              'description': description.text.trim(),
              'price': double.parse(price.text),
              'image': image.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  name.dispose();
  description.dispose();
  price.dispose();
  image.dispose();
  if (result == null) return;
  try {
    await firebaseService.savePromotion(id, result);
    if (context.mounted) showMessage(context, 'Promoción guardada.');
  } catch (error) {
    if (context.mounted) showMessage(context, 'Error: $error', error: true);
  }
}

class _AdminOrders extends StatefulWidget {
  const _AdminOrders();

  @override
  State<_AdminOrders> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<_AdminOrders> {
  String _status = 'Todos';
  String _branch = 'Todas';

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Branch>>(
    stream: firebaseService.branches(),
    builder: (context, branchesSnapshot) => StreamBuilder<List<OrderRecord>>(
      stream: firebaseService.orders(admin: true),
      builder: (context, ordersSnapshot) {
        if (ordersSnapshot.hasError) {
          return Center(child: Text('Error: ${ordersSnapshot.error}'));
        }
        if (!ordersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = ordersSnapshot.data!
            .where((item) => _status == 'Todos' || item.status == _status)
            .where((item) => _branch == 'Todas' || item.branchName == _branch)
            .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items:
                          [
                                'Todos',
                                'Pendiente',
                                'Confirmado',
                                'En preparación',
                                'En camino',
                                'Listo para recoger',
                                'Entregado',
                                'Cancelado',
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'Todos'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _branch,
                      decoration: const InputDecoration(labelText: 'Sucursal'),
                      items:
                          [
                                'Todas',
                                ...?branchesSnapshot.data?.map(
                                  (item) => item.name,
                                ),
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => _branch = value ?? 'Todas'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orders.isEmpty
                  ? const Center(
                      child: Text('No hay pedidos para estos filtros.'),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                      children: orders
                          .map(
                            (order) => OrderTile(order: order, isAdmin: true),
                          )
                          .toList(),
                    ),
            ),
          ],
        );
      },
    ),
  );
}
