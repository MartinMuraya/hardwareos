import '../models/plan.dart';

class FeatureAccessService {
  static const Map<String, List<String>> _planFeatures = {
    'trial': [
      'inventory',
      'sales',
      'expenses',
      'reports',
      'customers',
      'suppliers',
    ],
    'starter': [
      'inventory',
      'sales',
      'expenses',
      'reports',
      'customers',
      'suppliers',
    ],
    'pro': [
      'inventory',
      'sales',
      'expenses',
      'reports',
      'customers',
      'suppliers',
      'ai_assistant',
      'whatsapp_integration',
      'advanced_analytics',
      'forecasting',
    ],
  };

  /// Check if a plan has access to a specific feature
  static bool hasFeature(String planId, String feature) {
    final features = _planFeatures[planId] ?? [];
    return features.contains(feature);
  }

  /// Get all features for a plan
  static List<String> getFeatures(String planId) {
    return _planFeatures[planId] ?? [];
  }

  /// Get available features for a plan
  static List<String> getAvailableFeatures(Plan plan) {
    return _planFeatures[plan.id] ?? [];
  }

  /// Check if upgrade needed for feature
  static bool needsUpgrade(String currentPlan, String requiredFeature) {
    return !hasFeature(currentPlan, requiredFeature);
  }

  /// Get features available in Pro that are not in Starter
  static List<String> getProExclusiveFeatures() {
    final starterFeatures = Set.from(_planFeatures['starter'] ?? []);
    final proFeatures = _planFeatures['pro'] ?? [];
    return proFeatures.where((f) => !starterFeatures.contains(f)).toList();
  }

  /// Get all available plan IDs
  static List<String> getAvailablePlans() {
    return _planFeatures.keys.toList();
  }
}