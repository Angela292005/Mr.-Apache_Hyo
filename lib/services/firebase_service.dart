import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_models.dart';
import '../utils/product_image_url.dart';

class FirebaseService {
  FirebaseService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : auth = auth ?? FirebaseAuth.instance,
      firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  User? get currentUser => auth.currentUser;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get profileStream {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<void> register({
    required String nombres,
    required String apellidos,
    required String telefono,
    required String correo,
    required String password,
    String role = 'cliente',
  }) async {
    if (!const {'cliente', 'repartidor'}.contains(role)) {
      throw ArgumentError('Solo se permiten cuentas de cliente o repartidor.');
    }
    final normalizedNames = _normalizeName(nombres);
    final normalizedSurnames = _normalizeName(apellidos);
    final fullName = '$normalizedNames $normalizedSurnames';
    final credential = await auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(fullName);
    await firestore.collection('users').doc(credential.user!.uid).set({
      'nombres': normalizedNames,
      'apellidos': normalizedSurnames,
      'nombreCompleto': fullName,
      'telefono': telefono.trim(),
      'correo': correo.trim(),
      'role': role,
      'fechaRegistro': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensureClientProfile() async {
    final user = auth.currentUser;
    if (user == null) return;
    final displayName = user.displayName?.trim() ?? '';
    final parts = displayName.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    final nombres = parts.isEmpty ? 'Usuario' : parts.first;
    final apellidos = parts.length < 2 ? '' : parts.skip(1).join(' ');
    final doc = firestore.collection('users').doc(user.uid);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      if (snapshot.exists) return;
      transaction.set(doc, {
        'nombres': nombres,
        'apellidos': apellidos,
        'nombreCompleto': displayName.isEmpty ? nombres : displayName,
        'telefono': '',
        'correo': user.email?.trim() ?? '',
        'role': 'cliente',
        'fechaRegistro': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> signIn(String email, String password) => auth
      .signInWithEmailAndPassword(email: email.trim(), password: password)
      .then((_) {});

  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => auth.signOut();

  Future<void> updateProfile({
    required String nombres,
    required String apellidos,
    required String telefono,
  }) async {
    final user = currentUser!;
    final normalizedNames = _normalizeName(nombres);
    final normalizedSurnames = _normalizeName(apellidos);
    final fullName = '$normalizedNames $normalizedSurnames';
    await user.updateDisplayName(fullName);
    await firestore.collection('users').doc(user.uid).update({
      'nombres': normalizedNames,
      'apellidos': normalizedSurnames,
      'nombreCompleto': fullName,
      'telefono': telefono.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Branch>> branches() => firestore
      .collection('branches')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Branch.fromDoc).toList());

  Stream<List<Product>> products() => firestore
      .collection('products')
      .orderBy('name')
      .snapshots()
      .map((snapshot) {
        final products = snapshot.docs.map(Product.fromDoc).toList();
        return products.isEmpty ? defaultProducts : products;
      });

  Stream<List<Product>> firestoreProducts() => firestore
      .collection('products')
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Product.fromDoc).toList());

  static const List<Product> defaultProducts = [
    Product(
      id: 'combo_personal',
      name: 'Combo Personal',
      category: 'Combos',
      description: 'Pizza personal de jamón y queso + bebida personal 355 ml',
      image: '',
      available: true,
      prices: {'Único': 19},
    ),
    Product(
      id: 'combo_mediana',
      name: 'Combo Mediana',
      category: 'Combos',
      description: 'Pizza mediana de dos sabores + pan al ajo + bebida 1 L',
      image: '',
      available: true,
      prices: {'Único': 38.25},
    ),
    Product(
      id: 'combo_familiar',
      name: 'Combo Familiar',
      category: 'Combos',
      description:
          'Pizza familiar + pan al ajo con queso y chorizo + bebida 1 L',
      image: '',
      available: true,
      prices: {'Único': 51},
    ),
    Product(
      id: 'combo_familiar_especial',
      name: 'Combo Familiar Especial',
      category: 'Combos',
      description: 'Pizza familiar + pan al ajo + bebida especial 1 L',
      image: '',
      available: true,
      prices: {'Único': 59.41},
    ),
    Product(
      id: 'combo_pareja',
      name: 'Combo Pareja',
      category: 'Combos',
      description: 'Pizza mediana clásica + dos bebidas personales',
      image: '',
      available: true,
      prices: {'Único': 35},
    ),
    Product(
      id: 'combo_alitas_bbq',
      name: 'Combo Alitas BBQ',
      category: 'Combos',
      description: 'Alitas BBQ + gaseosa personal',
      image: '',
      available: true,
      prices: {'Único': 24},
    ),
    Product(
      id: 'combo_amigos',
      name: 'Combo Amigos',
      category: 'Combos',
      description: 'Dos pizzas personales + gaseosa de 1 L',
      image: '',
      available: true,
      prices: {'Único': 42},
    ),
    Product(
      id: 'a_lo_apache',
      name: 'A lo Apache',
      category: 'Pizzas',
      description:
          'Muzzarella, salame, chorizo, pepperoni, jamón inglés, champiñones, tocino, cabanossi y aceituna',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45},
    ),
    Product(
      id: 'extrema',
      name: 'Extrema',
      category: 'Pizzas',
      description:
          'Muzzarella, pepperoni, salame, chorizo, jamón inglés, champiñones y aceitunas',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45},
    ),
    Product(
      id: 'americana',
      name: 'Americana',
      category: 'Pizzas',
      description: 'Muzzarella, chorizo, jamón inglés y aceitunas',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 30, 'Familiar': 42},
    ),
    Product(
      id: 'endiablada',
      name: 'Endiablada',
      category: 'Pizzas',
      description:
          'Muzzarella, pollo, cabanossi, tocino, jamón inglés y rocoto',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45},
    ),
    Product(
      id: 'carn_vora',
      name: 'Carnívora',
      category: 'Pizzas',
      description: 'Muzzarella, chorizo, jamón inglés, pollo y res',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45},
    ),
    Product(
      id: 'hawaiana',
      name: 'Hawaiana',
      category: 'Pizzas',
      description: 'Muzzarella, jamón inglés, piña y durazno',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 30, 'Familiar': 42},
    ),
    Product(
      id: 'hawai_chicken',
      name: 'Hawai Chicken',
      category: 'Pizzas',
      description: 'Muzzarella, jamón inglés, piña y pollo',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 31, 'Familiar': 43},
    ),
    Product(
      id: 'tropical',
      name: 'Tropical',
      category: 'Pizzas',
      description: 'Muzzarella, salame, chorizo, jamón inglés, pollo y durazno',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45},
    ),
    Product(
      id: 'napolitana',
      name: 'Napolitana',
      category: 'Pizzas',
      description: 'Muzzarella, tomate, albahaca y aceitunas',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 30, 'Familiar': 42},
    ),
    Product(
      id: 'cuatro_quesos',
      name: 'Cuatro Quesos',
      category: 'Pizzas',
      description: 'Muzzarella, parmesano, queso andino y queso azul',
      image: '',
      available: true,
      prices: {'Personal': 15, 'Mediana': 34, 'Familiar': 48},
    ),
    Product(
      id: 'pollo_bbq',
      name: 'Pollo BBQ',
      category: 'Pizzas',
      description: 'Muzzarella, pollo, salsa BBQ y cebolla',
      image: '',
      available: true,
      prices: {'Personal': 14, 'Mediana': 32, 'Familiar': 45},
    ),
    Product(
      id: 'vegetariana',
      name: 'Vegetariana',
      category: 'Pizzas',
      description: 'Muzzarella, champiñones, pimientos, tomate y aceitunas',
      image: '',
      available: true,
      prices: {'Personal': 13.6, 'Mediana': 31, 'Familiar': 44},
    ),
    Product(
      id: 'suprema_apache',
      name: 'Suprema Apache',
      category: 'Pizzas',
      description: 'Muzzarella, chorizo regional, champiñones y pimientos',
      image: '',
      available: true,
      prices: {'Personal': 15, 'Mediana': 35, 'Familiar': 49},
    ),
    Product(
      id: 'lasagna_a_la_bolognesa',
      name: 'Lasagna a la Bolognesa',
      category: 'Pastas',
      description: 'Lasagna hecha al momento con salsa bolognesa',
      image: '',
      available: true,
      prices: {'Único': 15.3},
    ),
    Product(
      id: 'spaghetti_a_la_bolognesa',
      name: 'Spaghetti a la Bolognesa',
      category: 'Pastas',
      description: 'Spaghetti con salsa bolognesa',
      image: '',
      available: true,
      prices: {'Único': 12.75},
    ),
    Product(
      id: 'spaghetti_a_lo_apache',
      name: 'Spaghetti a lo Apache',
      category: 'Pastas',
      description: 'Spaghetti de la casa',
      image: '',
      available: true,
      prices: {'Único': 13.6},
    ),
    Product(
      id: 'spaghetti_a_lo_alfredo',
      name: 'Spaghetti a lo Alfredo',
      category: 'Pastas',
      description: 'Spaghetti con salsa Alfredo',
      image: '',
      available: true,
      prices: {'Único': 12.75},
    ),
    Product(
      id: 'fetucini_a_lo_apache',
      name: 'Fetucini a lo Apache',
      category: 'Pastas',
      description: 'Fetucini de la casa',
      image: '',
      available: true,
      prices: {'Único': 15.3},
    ),
    Product(
      id: 'fetucini_a_lo_alfredo',
      name: 'Fetucini a lo Alfredo',
      category: 'Pastas',
      description: 'Fetucini con salsa Alfredo',
      image: '',
      available: true,
      prices: {'Único': 13.6},
    ),
    Product(
      id: 'fetucini_a_la_bolognesa',
      name: 'Fetucini a la Bolognesa',
      category: 'Pastas',
      description: 'Fetucini con salsa bolognesa',
      image: '',
      available: true,
      prices: {'Único': 13.6},
    ),
    Product(
      id: 'ravioles_a_la_bolognesa',
      name: 'Ravioles a la Bolognesa',
      category: 'Pastas',
      description: 'Ravioles servidos con salsa bolognesa de la casa',
      image: '',
      available: true,
      prices: {'Único': 16},
    ),
    Product(
      id: 'lasagna_a_lo_alfredo',
      name: 'Lasagna a lo Alfredo',
      category: 'Pastas',
      description: 'Lasagna gratinada con salsa Alfredo',
      image: '',
      available: true,
      prices: {'Único': 16.5},
    ),
    Product(
      id: 'lomo_fino',
      name: 'Lomo Fino',
      category: 'Carnes y parrillas',
      description: 'Lomo fino a la parrilla',
      image: '',
      available: true,
      prices: {'Único': 21.25},
    ),
    Product(
      id: 'chuleta_de_cerdo',
      name: 'Chuleta de Cerdo',
      category: 'Carnes y parrillas',
      description: 'Chuleta de cerdo a la parrilla',
      image: '',
      available: true,
      prices: {'Único': 15.3},
    ),
    Product(
      id: 'costillas_bbq',
      name: 'Costillas BBQ',
      category: 'Carnes y parrillas',
      description: 'Costillas con salsa BBQ',
      image: '',
      available: true,
      prices: {'Único': 22.95},
    ),
    Product(
      id: 'pollo_a_la_parrilla',
      name: 'Pollo a la Parrilla',
      category: 'Carnes y parrillas',
      description: 'Pieza de pollo a la parrilla con guarnición',
      image: '',
      available: true,
      prices: {'Único': 19.5},
    ),
    Product(
      id: 'brochetas_de_res',
      name: 'Brochetas de Res',
      category: 'Carnes y parrillas',
      description: 'Brochetas de res a la parrilla con vegetales',
      image: '',
      available: true,
      prices: {'Único': 23},
    ),
    Product(
      id: 'milanesa_de_pollo',
      name: 'Milanesa de Pollo',
      category: 'Carnes y parrillas',
      description: 'Milanesa de pollo dorada con guarnición',
      image: '',
      available: true,
      prices: {'Único': 18},
    ),
    Product(
      id: 'limonada_1_l',
      name: 'Limonada 1 L',
      category: 'Bebidas',
      description: 'Limonada de la casa',
      image: '',
      available: true,
      prices: {'Único': 10},
    ),
    Product(
      id: 'gaseosa_personal',
      name: 'Gaseosa personal',
      category: 'Bebidas',
      description: 'Gaseosa personal 355 ml',
      image: '',
      available: true,
      prices: {'Único': 4},
    ),
    Product(
      id: 'gaseosa_1_l',
      name: 'Gaseosa 1 L',
      category: 'Bebidas',
      description: 'Gaseosa familiar 1 L',
      image: '',
      available: true,
      prices: {'Único': 8},
    ),
    Product(
      id: 'caldo_y_hierbas_calientes',
      name: 'Caldo y hierbas calientes',
      category: 'Bebidas',
      description: 'Bebida caliente de hierbas',
      image: '',
      available: true,
      prices: {'Único': 6},
    ),
    Product(
      id: 'vino_de_la_casa',
      name: 'Vino de la casa',
      category: 'Bebidas',
      description: 'Vino de la casa, consultar disponibilidad',
      image: '',
      available: true,
      prices: {'Único': 25},
    ),
    Product(
      id: 'chicha_morada',
      name: 'Chicha Morada',
      category: 'Bebidas',
      description: 'Chicha morada de la casa',
      image: '',
      available: true,
      prices: {'Único': 8},
    ),
    Product(
      id: 'inka_kola_1_5_l',
      name: 'Inka Kola 1.5 L',
      category: 'Bebidas',
      description: 'Gaseosa Inka Kola familiar de 1.5 L',
      image: '',
      available: true,
      prices: {'Único': 12},
    ),
    Product(
      id: 'limonada_personal',
      name: 'Limonada Personal',
      category: 'Bebidas',
      description: 'Limonada de la casa en vaso personal',
      image: '',
      available: true,
      prices: {'Único': 6},
    ),
    Product(
      id: 'cerveza_artesanal',
      name: 'Cerveza Artesanal',
      category: 'Bebidas',
      description: 'Cerveza artesanal andina, sujeto a disponibilidad',
      image: '',
      available: true,
      prices: {'Único': 15},
    ),
    Product(
      id: 'pan_al_ajo',
      name: 'Pan al ajo',
      category: 'Extras',
      description: 'Pan al ajo recién horneado',
      image: '',
      available: true,
      prices: {'Único': 8},
    ),
    Product(
      id: 'alitas_bbq',
      name: 'Alitas BBQ',
      category: 'Extras',
      description: 'Porción de alitas con salsa BBQ',
      image: '',
      available: true,
      prices: {'Único': 20},
    ),
    Product(
      id: 'papas_fritas',
      name: 'Papas Fritas',
      category: 'Extras',
      description: 'Porción de papas fritas crocantes',
      image: '',
      available: true,
      prices: {'Único': 9},
    ),
    Product(
      id: 'pan_al_ajo_con_queso',
      name: 'Pan al Ajo con Queso',
      category: 'Extras',
      description: 'Pan al ajo horneado con queso gratinado',
      image: '',
      available: true,
      prices: {'Único': 12},
    ),
  ];

  Stream<List<OrderRecord>> orders({required bool admin}) {
    final user = currentUser!;
    final query = firestore.collection('orders');
    return (admin
            ? query.orderBy('createdAt', descending: true)
            : query.where('userId', isEqualTo: user.uid))
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs.map(OrderRecord.fromDoc).toList();
          if (!admin) {
            orders.sort((a, b) {
              final dateA =
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final dateB =
                  b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return dateB.compareTo(dateA);
            });
          }
          return orders;
        });
  }

  Future<void> submitOrder({
    required List<CartItem> items,
    required Branch branch,
    required String deliveryType,
    required String address,
    required String payment,
    required String notes,
    required double deliveryFee,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    final user = currentUser!;
    final userSnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = UserModel.fromMap(userSnapshot.data() ?? {}, id: user.uid);
    final document = firestore.collection('orders').doc();
    final number = 'MA-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final subtotal = items.fold<double>(
      0,
      (total, item) => total + item.subtotal,
    );
    await document.set({
      'number': number,
      'userId': user.uid,
      'customerName': userData.nombreCompleto.isEmpty
          ? user.displayName ?? ''
          : userData.nombreCompleto,
      'customerFirstName': userData.nombres,
      'customerLastName': userData.apellidos,
      'customerPhone': userData.telefono,
      'items': items
          .map(
            (item) => {
              'productId': item.product.id,
              'name': item.product.name,
              'category': item.product.category,
              'size': item.size,
              'quantity': item.quantity,
              'unitPrice': item.unitPrice,
              'subtotal': item.subtotal,
              'notes': item.notes,
            },
          )
          .toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': subtotal + deliveryFee,
      'branchId': branch.id,
      'branchName': branch.name,
      'deliveryType': deliveryType,
      'address': address,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'payment': payment,
      'notes': notes,
      'status': 'Pendiente',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'business': {
        'name': 'Pizzería-Restaurant Mr. Apache',
        'legalName': 'Inversiones Cesarvero S.A.C.',
        'ruc': '20612033111',
      },
    });
  }

  Future<void> updateOrderLocation(
    String orderId,
    double latitude,
    double longitude,
  ) => firestore.collection('orders').doc(orderId).set({
    'tracking': {
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    },
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> acceptOrder(String orderId) async {
    final courier = currentUser!;
    final profile = await firestore.collection('users').doc(courier.uid).get();
    final data = profile.data() ?? {};
    final courierName = (data['nombreCompleto'] as String?)?.trim().isNotEmpty == true
        ? (data['nombreCompleto'] as String).trim()
        : courier.displayName ?? 'Repartidor';

    await firestore.runTransaction((transaction) async {
      final reference = firestore.collection('orders').doc(orderId);
      final snapshot = await transaction.get(reference);
      final order = snapshot.data() ?? {};
      final assignedCourier = order['courierId']?.toString() ?? '';
      final declined = List<String>.from(order['declinedCouriers'] as List? ?? const []);
      if (assignedCourier.isNotEmpty) throw Exception('Este pedido ya fue aceptado por otro repartidor.');
      if (declined.contains(courier.uid)) throw Exception('Este pedido fue rechazado por ti.');
      transaction.update(reference, {
        'courierId': courier.uid,
        'courierName': courierName,
        'acceptedAt': FieldValue.serverTimestamp(),
        'status': 'Confirmado',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> declineOrder(String orderId) async {
    final courier = currentUser!;
    await firestore.collection('orders').doc(orderId).update({
      'declinedCouriers': FieldValue.arrayUnion([courier.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelOrder(String orderId) =>
      firestore.collection('orders').doc(orderId).update({
        'status': 'Cancelado',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setOrderStatus(String orderId, String status) => firestore
      .collection('orders')
      .doc(orderId)
      .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> saveProduct(String? id, Map<String, dynamic> data) async {
    final collection = firestore.collection('products');
    if (id == null) {
      await collection.add(data);
    } else {
      await collection.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> deleteDocument(String collection, String id) =>
      firestore.collection(collection).doc(id).delete();

  Future<void> saveBranch(String? id, Map<String, dynamic> data) async {
    final collection = firestore.collection('branches');
    if (id == null) {
      await collection.add(data);
    } else {
      await collection.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> savePromotion(String? id, Map<String, dynamic> data) async {
    final collection = firestore.collection('promotions');
    if (id == null) {
      await collection.add(data);
    } else {
      await collection.doc(id).set(data, SetOptions(merge: true));
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> promotions() =>
      firestore.collection('promotions').snapshots();

  CollectionReference<Map<String, dynamic>> get _ownAddresses => firestore
      .collection('users')
      .doc(currentUser!.uid)
      .collection('addresses');

  Stream<QuerySnapshot<Map<String, dynamic>>> addresses() =>
      _ownAddresses.orderBy('createdAt').snapshots();

  Future<void> saveAddress(String? id, Map<String, dynamic> data) async {
    if (data['primary'] == true) {
      final existing = await _ownAddresses.get();
      final batch = firestore.batch();
      for (final document in existing.docs) {
        batch.update(document.reference, {'primary': false});
      }
      await batch.commit();
    }
    if (id == null) {
      await _ownAddresses.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _ownAddresses.doc(id).update(data);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reviews() => firestore
      .collection('reviews')
      .where('userId', isEqualTo: currentUser!.uid)
      .snapshots();

  Future<void> saveReview({
    String? id,
    required int stars,
    required String comment,
  }) async {
    final collection = firestore.collection('reviews');
    final user = currentUser!;
    final userSnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final userModel = UserModel.fromMap(
      userSnapshot.data() ?? {},
      id: user.uid,
    );
    final values = {
      'userId': user.uid,
      'customerName': userModel.nombreCompleto.isEmpty
          ? user.displayName ?? ''
          : userModel.nombreCompleto,
      'stars': stars,
      'comment': comment.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      await collection.add({
        ...values,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await collection.doc(id).update(values);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> reservations() => firestore
      .collection('reservations')
      .where('userId', isEqualTo: currentUser!.uid)
      .snapshots();

  Future<void> saveReservation({
    String? id,
    required DateTime date,
    required String time,
    required int people,
    required Branch branch,
  }) async {
    final collection = firestore.collection('reservations');
    final values = {
      'userId': currentUser!.uid,
      'date': Timestamp.fromDate(date),
      'time': time,
      'people': people,
      'branchId': branch.id,
      'branchName': branch.name,
      'status': 'Reservada',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      await collection.add({
        ...values,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await collection.doc(id).update(values);
    }
  }

  Future<int> seedInitialData() async {
    final batch = firestore.batch();
    final branches = [
      {
        'id': 'san_carlos',
        'name': 'Mr. Apache – San Carlos',
        'address': 'Av. San Carlos 760 (también Av. San Carlos 716), Huancayo',
      },
      {
        'id': 'pio_pata',
        'name': 'Mr. Apache Pío Pata',
        'address': 'Jr. Colón 100, El Tambo, Huancayo',
      },
      {
        'id': 'parra_del_riego',
        'name': 'Pizzería-Restaurant Mr. Apache – Parra del Riego',
        'address': 'Jr. Parra del Riego 575, El Tambo, Huancayo',
      },
    ];
    for (final branch in branches) {
      final id = branch.remove('id') as String;
      batch.set(firestore.collection('branches').doc(id), {
        ...branch,
        'phone': '+51 985 595 558',
        'openingTime': '16:00',
        'closingTime': '00:00',
        'lunchOpeningTime': '12:30',
        'lunchClosingTime': '14:30',
        'acceptsDelivery': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    const categories = [
      'Combos',
      'Pizzas',
      'Pastas',
      'Carnes y parrillas',
      'Bebidas',
      'Extras',
    ];
    for (final category in categories) {
      batch.set(
        firestore.collection('categories').doc(_slug(category)),
        {'name': category},
        SetOptions(merge: true),
      );
    }

    final productsCollection = firestore.collection('products');
    final existingProducts = await productsCollection.get();
    final existingImages = {
      for (final doc in existingProducts.docs)
        doc.id: doc.data()['image'] as String? ?? '',
    };
    for (final product in defaultProducts) {
      final id = product.id;
      final savedImage = existingImages[id]?.trim() ?? '';
      batch.set(productsCollection.doc(id), {
        'name': product.name,
        'category': product.category,
        'description': product.description,
        'prices': product.prices,
        'available': true,
        'image': productImageUrl(product, existingImage: savedImage),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    return defaultProducts.length;
  }

  static String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static String _normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
