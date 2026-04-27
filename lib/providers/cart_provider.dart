import 'package:flutter/material.dart';
import '../models/product.dart';

class CartItem {
  final Product product;
  final String size;
  final String color;
  int quantity;

  CartItem({
    required this.product,
    required this.size,
    required this.color,
    this.quantity = 1,
  });

  String get key => '${product.id}-$size-$color';
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get total => _items.fold(0, (sum, i) => sum + i.product.price * i.quantity);

  void addItem(Product product, String size, String color) {
    final existing = _items.firstWhere(
      (i) => i.product.id == product.id && i.size == size && i.color == color,
      orElse: () => CartItem(product: product, size: size, color: color, quantity: 0),
    );
    if (_items.contains(existing)) {
      existing.quantity++;
    } else {
      _items.add(CartItem(product: product, size: size, color: color));
    }
    notifyListeners();
  }

  void removeItem(String key) {
    _items.removeWhere((i) => i.key == key);
    notifyListeners();
  }

  void updateQuantity(String key, int quantity) {
    if (quantity <= 0) {
      removeItem(key);
      return;
    }
    final item = _items.firstWhere((i) => i.key == key);
    item.quantity = quantity;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
