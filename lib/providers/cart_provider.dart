import 'package:flutter/foundation.dart';

import '../models/app_models.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? selectedBranchId;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  void selectBranch(String? id) {
    selectedBranchId = id;
    notifyListeners();
  }

  void add(Product product, {required String size, String notes = ''}) {
    final existing = _items.where(
      (item) => item.product.id == product.id && item.size == size && item.notes == notes,
    );
    if (existing.isNotEmpty) {
      existing.first.quantity++;
    } else {
      _items.add(
        CartItem(product: product, size: size, quantity: 1, notes: notes),
      );
    }
    notifyListeners();
  }

  void setQuantity(CartItem item, int quantity) {
    if (quantity < 1) {
      _items.remove(item);
    } else {
      item.quantity = quantity;
    }
    notifyListeners();
  }

  void remove(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
