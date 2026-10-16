import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.nombreCompleto,
    required this.telefono,
    required this.correo,
    required this.role,
    this.fechaRegistro,
  });

  final String id;
  final String nombres;
  final String apellidos;
  final String nombreCompleto;
  final String telefono;
  final String correo;
  final String role;
  final DateTime? fechaRegistro;

  factory UserModel.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    final first = (data['nombres'] as String? ?? '').trim();
    final last = (data['apellidos'] as String? ?? '').trim();
    final legacyFullName =
        (data['nombreCompleto'] as String? ??
                data['name'] as String? ??
                data['nombre'] as String? ??
                '')
            .trim();
    final legacyParts = legacyFullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final names = first.isNotEmpty
        ? first
        : legacyParts.isEmpty
        ? ''
        : legacyParts.first;
    final surnames = last.isNotEmpty
        ? last
        : legacyParts.length < 2
        ? ''
        : legacyParts.skip(1).join(' ');
    final full = '$names $surnames'.trim();
    final timestamp = data['fechaRegistro'] as Timestamp? ??
        data['createdAt'] as Timestamp?;
    return UserModel(
      id: id,
      nombres: names,
      apellidos: surnames,
      nombreCompleto: full.isEmpty ? legacyFullName : full,
      telefono: (data['telefono'] as String? ?? data['phone'] as String? ?? '')
          .trim(),
      correo: (data['correo'] as String? ?? data['email'] as String? ?? '')
          .trim(),
      role: data['role'] as String? ?? 'cliente',
      fechaRegistro: timestamp?.toDate(),
    );
  }
}

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.openingTime,
    required this.closingTime,
    required this.acceptsDelivery,
    this.lunchOpeningTime = '12:30',
    this.lunchClosingTime = '14:30',
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final String openingTime;
  final String closingTime;
  final bool acceptsDelivery;
  final String lunchOpeningTime;
  final String lunchClosingTime;

  factory Branch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Branch(
      id: doc.id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      openingTime: data['openingTime'] as String? ?? '16:00',
      closingTime: data['closingTime'] as String? ?? '00:00',
      acceptsDelivery: data['acceptsDelivery'] as bool? ?? true,
      lunchOpeningTime: data['lunchOpeningTime'] as String? ?? '12:30',
      lunchClosingTime: data['lunchClosingTime'] as String? ?? '14:30',
    );
  }

  bool get isOpen {
    final now = DateTime.now();
    final start = _minutes(openingTime);
    final end = _minutes(closingTime);
    final current = now.hour * 60 + now.minute;
    final dinner = start <= end
        ? current >= start && current < end
        : current >= start || current < end;
    final lunchStart = _minutes(lunchOpeningTime);
    final lunchEnd = _minutes(lunchClosingTime);
    final lunch = now.weekday <= DateTime.friday &&
        current >= lunchStart &&
        current < lunchEnd;
    return dinner || lunch;
  }

  static int _minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.image,
    required this.available,
    required this.prices,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String image;
  final bool available;
  final Map<String, double> prices;

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawPrices = Map<String, dynamic>.from(data['prices'] as Map? ?? {});
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Extras',
      description: data['description'] as String? ?? '',
      image: data['image'] as String? ?? '',
      available: data['available'] as bool? ?? true,
      prices: rawPrices.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }

  double get startingPrice =>
      prices.values.isEmpty ? 0 : prices.values.reduce((a, b) => a < b ? a : b);
}

class CartItem {
  CartItem({
    required this.product,
    required this.size,
    required this.quantity,
    this.notes = '',
  });

  final Product product;
  final String size;
  int quantity;
  String notes;

  double get unitPrice => product.prices[size] ?? product.startingPrice;
  double get subtotal => unitPrice * quantity;
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.number,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.branchName,
    required this.items,
    required this.deliveryType,
    required this.address,
    this.customerName = '',
    this.customerPhone = '',
  });

  final String id;
  final String number;
  final String status;
  final double total;
  final DateTime? createdAt;
  final String branchName;
  final List<Map<String, dynamic>> items;
  final String deliveryType;
  final String address;
  final String customerName;
  final String customerPhone;

  factory OrderRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return OrderRecord(
      id: doc.id,
      number: data['number'] as String? ?? doc.id,
      status: data['status'] as String? ?? 'Pendiente',
      total: (data['total'] as num? ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      branchName: data['branchName'] as String? ?? '',
      items: List<Map<String, dynamic>>.from(data['items'] as List? ?? []),
      deliveryType: data['deliveryType'] as String? ?? '',
      address: data['address'] as String? ?? '',
      customerName: data['customerName'] as String? ??
          data['name'] as String? ??
          '',
      customerPhone: data['customerPhone'] as String? ??
          data['phone'] as String? ??
          '',
    );
  }
}
