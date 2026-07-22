import 'package:flutter_test/flutter_test.dart';
import 'package:hardwareos/core/models/product.dart';

void main() {
  group('Product Model Tests', () {
    test('isOutOfStock correctly identifies stock status', () {
      final product = Product(
        id: '1',
        businessId: 'b1',
        name: 'Hammer',
        sku: 'H1',
        category: 'Tools',
        quantity: 0,
        costPrice: 500,
        sellingPrice: 1000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(product.isOutOfStock, isTrue);
    });

    test('isLowStock correctly identifies low stock status', () {
      final product = Product(
        id: '1',
        businessId: 'b1',
        name: 'Hammer',
        sku: 'H1',
        category: 'Tools',
        quantity: 5,
        reorderLevel: 10,
        costPrice: 500,
        sellingPrice: 1000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(product.isLowStock, isTrue);
    });

    test('fromMap parses valid data', () {
      final data = {
        'id': '1',
        'businessId': 'b1',
        'name': 'Hammer',
        'sku': 'H1',
        'category': 'Tools',
        'quantity': 20,
        'costPrice': 500.0,
        'sellingPrice': 1000.0,
        'createdAt': '2023-01-01T00:00:00.000Z',
        'updatedAt': '2023-01-01T00:00:00.000Z',
      };
      final product = Product.fromMap(data);
      expect(product.name, 'Hammer');
      expect(product.quantity, 20);
      expect(product.sellingPrice, 1000.0);
    });
  });
}
