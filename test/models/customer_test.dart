import 'package:flutter_test/flutter_test.dart';
import 'package:hardwareos/core/models/customer.dart';

void main() {
  group('Customer Model Tests', () {
    test('Customer.fromMap parses standard fields correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'cust_001',
        'businessId': 'biz_001',
        'fullName': 'Juma Otieno',
        'phoneNumber': '0712345678',
        'email': 'juma@example.com',
        'address': 'Nairobi',
        'notes': 'Fundi for Westlands site',
        'creditLimit': 50000.0,
        'currentBalance': 15000.0,
        'loyaltyPoints': 120.0,
        'isFundi': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final customer = Customer.fromMap(map);

      expect(customer.id, 'cust_001');
      expect(customer.fullName, 'Juma Otieno');
      expect(customer.phoneNumber, '0712345678');
      expect(customer.creditLimit, 50000.0);
      expect(customer.currentBalance, 15000.0);
      expect(customer.availableCredit, 35000.0);
      expect(customer.isOverLimit, false);
      expect(customer.loyaltyPoints, 120.0);
      expect(customer.isFundi, true);
    });

    test('isOverLimit detects balance exceeding credit limit', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'c2',
        businessId: 'b1',
        fullName: 'Jane Doe',
        phoneNumber: '0711111111',
        creditLimit: 10000.0,
        currentBalance: 12000.0,
        createdAt: now,
        updatedAt: now,
      );

      expect(customer.isOverLimit, true);
      expect(customer.availableCredit, 0.0);
    });

    test('toMap converts customer correctly', () {
      final now = DateTime.now();
      final customer = Customer(
        id: 'c3',
        businessId: 'b1',
        fullName: 'Kamau Hardware Supplier',
        phoneNumber: '0700000000',
        creditLimit: 20000.0,
        currentBalance: 5000.0,
        isFundi: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = customer.toMap();
      expect(map['fullName'], 'Kamau Hardware Supplier');
      expect(map['creditLimit'], 20000.0);
      expect(map['currentBalance'], 5000.0);
      expect(map['isFundi'], false);
    });
  });
}
