import 'package:flutter_test/flutter_test.dart';
import 'package:hardwareos/core/models/product.dart';

void main() {
  group('Product Model Tests', () {
    test('Product.fromMap correctly parses standard fields', () {
      final now = DateTime.now();
      final map = {
        'id': 'prod_123',
        'businessId': 'biz_456',
        'name': 'Cement 50kg',
        'sku': 'CEM-50',
        'category': 'Building Materials',
        'quantity': 100,
        'costPrice': 550.0,
        'sellingPrice': 650.0,
        'reorderLevel': 20,
        'barcodes': ['123456789'],
        'isWeighed': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final product = Product.fromMap(map);

      expect(product.id, 'prod_123');
      expect(product.name, 'Cement 50kg');
      expect(product.quantity, 100.0);
      expect(product.costPrice, 550.0);
      expect(product.sellingPrice, 650.0);
      expect(product.barcodes.first, '123456789');
      expect(product.isWeighed, false);
      expect(product.isLowStock, false);
      expect(product.isOutOfStock, false);
    });

    test('Product.fromMap safely parses missing or null fields', () {
      final map = {
        'id': 'prod_456',
        'businessId': 'biz_456',
        'name': 'Loose Nails',
        // Missing sku, category, barcodes
        'quantity': 0,
        'buyingPrice': 100.0, // Tests the fallback from costPrice
        'sellingPrice': 150.0,
        'reorderLevel': null,
        'isWeighed': true,
      };

      final product = Product.fromMap(map);

      expect(product.sku, '');
      expect(product.category, 'General');
      expect(product.quantity, 0.0);
      expect(product.costPrice, 100.0); // Fallback applied
      expect(product.barcodes, isEmpty);
      expect(product.isWeighed, true);
      expect(product.isOutOfStock, true); // Since qty is 0
    });

    test('Product.copyWith updates fields correctly', () {
      final product = Product(
        id: '1', businessId: 'b', name: 'Item', sku: 'S', category: 'C',
        quantity: 10, costPrice: 5, sellingPrice: 10, reorderLevel: 2,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );

      final updated = product.copyWith(
        quantity: 5,
        sellingPrice: 12,
      );

      expect(updated.quantity, 5);
      expect(updated.sellingPrice, 12);
      expect(updated.name, 'Item'); // unchanged
    });
  });
}
