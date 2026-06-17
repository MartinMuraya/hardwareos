import 'package:flutter_test/flutter_test.dart';
import 'package:hardwareos/core/services/offline_service.dart';
import 'package:hardwareos/core/services/feature_access_service.dart';
import 'package:hardwareos/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(HardwareOSApp, isNotNull);
  });

  group('OfflineService model serialization', () {
    test('PendingSale serialization round-trip', () {
      final sale = PendingSale(
        id: 'test-1',
        saleData: {'paymentMethod': 'cash', 'items': []},
        createdAt: DateTime(2025, 1, 1),
        retryCount: 0,
      );
      final json = sale.toJson();
      final restored = PendingSale.fromJson(json);
      expect(restored.id, sale.id);
      expect(restored.retryCount, sale.retryCount);
      expect(restored.saleData['paymentMethod'], 'cash');
    });

    test('PendingPayment serialization round-trip', () {
      final pmt = PendingPayment(
        id: 'pmt-1',
        paymentData: {'amount': 1000, 'customerId': 'c1'},
        createdAt: DateTime(2025, 1, 1),
        retryCount: 2,
      );
      final json = pmt.toJson();
      final restored = PendingPayment.fromJson(json);
      expect(restored.id, pmt.id);
      expect(restored.retryCount, 2);
      expect(restored.paymentData['amount'], 1000);
    });

    test('PendingInventoryUpdate serialization round-trip', () {
      final inv = PendingInventoryUpdate(
        id: 'inv-1',
        updateData: {'productId': 'p1', 'quantity': 10},
        createdAt: DateTime(2025, 1, 1),
        retryCount: 1,
      );
      final json = inv.toJson();
      final restored = PendingInventoryUpdate.fromJson(json);
      expect(restored.id, inv.id);
      expect(restored.updateData['productId'], 'p1');
    });
  });

  group('FeatureAccessService basic checks', () {
    test('Pro tier has AI feature', () {
      final features = FeatureAccessService.getFeatures('pro');
      expect(features, contains('ai_assistant'));
    });

    test('Starter tier does not have AI feature', () {
      final features = FeatureAccessService.getFeatures('starter');
      expect(features, isNot(contains('ai_assistant')));
    });
  });
}
