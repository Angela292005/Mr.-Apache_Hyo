import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_models.dart';

class FirebaseService {
  FirebaseService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : auth = auth ?? FirebaseAuth.instance,
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
  }) async {
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
      'role': 'cliente',
      'fechaRegistro': FieldValue.serverTimestamp(),
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
      .map((snapshot) => snapshot.docs.map(Product.fromDoc).toList());

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
              final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
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
  }) async {
    final user = currentUser!;
    final userSnapshot = await firestore.collection('users').doc(user.uid).get();
    final userData = UserModel.fromMap(
      userSnapshot.data() ?? {},
      id: user.uid,
    );
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

  Future<void> cancelOrder(String orderId) => firestore
      .collection('orders')
      .doc(orderId)
      .update({'status': 'Cancelado', 'updatedAt': FieldValue.serverTimestamp()});

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

  CollectionReference<Map<String, dynamic>> get _ownAddresses =>
      firestore.collection('users').doc(currentUser!.uid).collection('addresses');

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
    final userSnapshot = await firestore.collection('users').doc(user.uid).get();
    final userModel = UserModel.fromMap(userSnapshot.data() ?? {}, id: user.uid);
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

  Future<void> seedInitialData() async {
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

    final records = <Map<String, dynamic>>[
      _product('Combo Personal', 'Combos', 'Pizza personal de jamón y queso + bebida personal 355 ml', {'Único': 19}),
      _product('Combo Mediana', 'Combos', 'Pizza mediana de dos sabores + pan al ajo + bebida 1 L', {'Único': 38.25}),
      _product('Combo Familiar', 'Combos', 'Pizza familiar + pan al ajo con queso y chorizo + bebida 1 L', {'Único': 51}),
      _product('Combo Familiar Especial', 'Combos', 'Pizza familiar + pan al ajo + bebida especial 1 L', {'Único': 59.41}),
      _product('A lo Apache', 'Pizzas', 'Muzzarella, salame, chorizo, pepperoni, jamón inglés, champiñones, tocino, cabanossi y aceituna', {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45}),
      _product('Extrema', 'Pizzas', 'Muzzarella, pepperoni, salame, chorizo, jamón inglés, champiñones y aceitunas', {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45}),
      _product('Americana', 'Pizzas', 'Muzzarella, chorizo, jamón inglés y aceitunas', {'Personal': 13.6, 'Mediana': 30, 'Familiar': 42}),
      _product('Endiablada', 'Pizzas', 'Muzzarella, pollo, cabanossi, tocino, jamón inglés y rocoto', {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45}),
      _product('Carnívora', 'Pizzas', 'Muzzarella, chorizo, jamón inglés, pollo y res', {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45}),
      _product('Hawaiana', 'Pizzas', 'Muzzarella, jamón inglés, piña y durazno', {'Personal': 13.6, 'Mediana': 30, 'Familiar': 42}),
      _product('Hawai Chicken', 'Pizzas', 'Muzzarella, jamón inglés, piña y pollo', {'Personal': 13.6, 'Mediana': 31, 'Familiar': 43}),
      _product('Tropical', 'Pizzas', 'Muzzarella, salame, chorizo, jamón inglés, pollo y durazno', {'Personal': 13.6, 'Mediana': 32, 'Familiar': 45}),
      _product('Lasagna a la Bolognesa', 'Pastas', 'Lasagna hecha al momento con salsa bolognesa', {'Único': 15.3}),
      _product('Spaghetti a la Bolognesa', 'Pastas', 'Spaghetti con salsa bolognesa', {'Único': 12.75}),
      _product('Spaghetti a lo Apache', 'Pastas', 'Spaghetti de la casa', {'Único': 13.6}),
      _product('Spaghetti a lo Alfredo', 'Pastas', 'Spaghetti con salsa Alfredo', {'Único': 12.75}),
      _product('Fetucini a lo Apache', 'Pastas', 'Fetucini de la casa', {'Único': 15.3}),
      _product('Fetucini a lo Alfredo', 'Pastas', 'Fetucini con salsa Alfredo', {'Único': 13.6}),
      _product('Fetucini a la Bolognesa', 'Pastas', 'Fetucini con salsa bolognesa', {'Único': 13.6}),
      _product('Lomo Fino', 'Carnes y parrillas', 'Lomo fino a la parrilla', {'Único': 21.25}),
      _product('Chuleta de Cerdo', 'Carnes y parrillas', 'Chuleta de cerdo a la parrilla', {'Único': 15.3}),
      _product('Costillas BBQ', 'Carnes y parrillas', 'Costillas con salsa BBQ', {'Único': 22.95}),
      _product('Limonada 1 L', 'Bebidas', 'Limonada de la casa', {'Único': 10}),
      _product('Gaseosa personal', 'Bebidas', 'Gaseosa personal 355 ml', {'Único': 4}),
      _product('Gaseosa 1 L', 'Bebidas', 'Gaseosa familiar 1 L', {'Único': 8}),
      _product('Caldo y hierbas calientes', 'Bebidas', 'Bebida caliente de hierbas', {'Único': 6}),
      _product('Vino de la casa', 'Bebidas', 'Vino de la casa, consultar disponibilidad', {'Único': 25}),
      _product('Pan al ajo', 'Extras', 'Pan al ajo recién horneado', {'Único': 8}),
    ];
    for (final product in records) {
      final id = _slug(product['name'] as String);
      batch.set(firestore.collection('products').doc(id), {
        ...product,
        'available': true,
        'image': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  static Map<String, dynamic> _product(
    String name,
    String category,
    String description,
    Map<String, num> prices,
  ) => {
    'name': name,
    'category': category,
    'description': description,
    'prices': prices,
  };

  static String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static String _normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}
