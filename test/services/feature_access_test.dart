import 'package:flutter_test/flutter_test.dart';
import 'package:hardwareos/core/providers/business_provider.dart';

void main() {
  group('Feature Access Tests (Business Provider)', () {
    test('isPro returns true when plan is pro', () {
      final provider = BusinessProvider();
      provider.updateMockPlan('pro');
      expect(provider.isPro, isTrue);
    });

    test('isPro returns false when plan is starter', () {
      final provider = BusinessProvider();
      provider.updateMockPlan('starter');
      expect(provider.isPro, isFalse);
    });

    test('hasFeature returns true for basic features on starter', () {
      final provider = BusinessProvider();
      provider.updateMockPlan('starter');
      expect(provider.hasFeature('inventory'), isTrue);
    });

    test('hasFeature returns false for pro features on starter', () {
      final provider = BusinessProvider();
      provider.updateMockPlan('starter');
      expect(provider.hasFeature('advanced_analytics'), isFalse);
    });
  });
}
