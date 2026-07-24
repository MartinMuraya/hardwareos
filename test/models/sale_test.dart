import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sale Business Logic Tests', () {
    test('Loyalty points calculation logic (1 pt per KES 100)', () {
      double totalSale = 4500.0;
      int pointsEarned = (totalSale / 100).floor();
      expect(pointsEarned, 45);
    });

    test('Sale totals and item line calculations', () {
      final items = [
        {'name': 'Cement', 'quantity': 5, 'sellingPrice': 750.0},
        {'name': 'Nails 2 inch', 'quantity': 2, 'sellingPrice': 200.0},
      ];

      double calculatedTotal = 0;
      for (final item in items) {
        calculatedTotal += (item['quantity'] as num) * (item['sellingPrice'] as num);
      }

      expect(calculatedTotal, 4150.0);
    });
  });
}
