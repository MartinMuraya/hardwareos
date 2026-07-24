import 'package:flutter_test/flutter_test.dart';
import 'package:hardwareos/core/services/feature_access_service.dart';

void main() {
  group('FeatureAccessService Tests', () {
    test('Starter plan features check', () {
      expect(FeatureAccessService.hasFeature('starter', 'inventory'), true);
      expect(FeatureAccessService.hasFeature('starter', 'sales'), true);
      expect(FeatureAccessService.hasFeature('starter', 'ai_assistant'), false);
      expect(FeatureAccessService.hasFeature('starter', 'whatsapp_integration'), false);
    });

    test('Pro plan features check', () {
      expect(FeatureAccessService.hasFeature('pro', 'inventory'), true);
      expect(FeatureAccessService.hasFeature('pro', 'ai_assistant'), true);
      expect(FeatureAccessService.hasFeature('pro', 'whatsapp_integration'), true);
      expect(FeatureAccessService.hasFeature('pro', 'advanced_analytics'), true);
    });

    test('needsUpgrade detects missing features', () {
      expect(FeatureAccessService.needsUpgrade('starter', 'ai_assistant'), true);
      expect(FeatureAccessService.needsUpgrade('pro', 'ai_assistant'), false);
    });

    test('getProExclusiveFeatures returns pro-only items', () {
      final proExclusive = FeatureAccessService.getProExclusiveFeatures();
      expect(proExclusive, contains('ai_assistant'));
      expect(proExclusive, contains('whatsapp_integration'));
      expect(proExclusive, contains('advanced_analytics'));
      expect(proExclusive, isNot(contains('inventory')));
    });

    test('Grace period restrictions applied correctly', () {
      final starterNormal = FeatureAccessService.getFeatures('starter', isGracePeriod: false);
      final starterGrace = FeatureAccessService.getFeatures('starter', isGracePeriod: true);

      expect(starterNormal, contains('sales'));
      expect(starterGrace, isNot(contains('sales')));
    });
  });
}
