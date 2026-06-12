import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to seed initial plans into Firestore
/// Run this once during app initialization or via a setup screen
class PlanSeeder {
  static final _db = FirebaseFirestore.instance;

  /// Seed default plans into the plans collection
  /// Returns true if successful
  static Future<bool> seedPlans() async {
    try {
      final batch = _db.batch();

      // Starter Plan
      batch.set(
        _db.collection('plans').doc('starter'),
        {
          'id': 'starter',
          'name': 'Starter',
          'price': 2600,
          'currency': 'KES',
          'billingCycle': 'monthly',
          'maxUsers': 5,
          'features': [
            'inventory',
            'sales',
            'expenses',
            'reports',
            'customers',
            'suppliers',
          ],
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      // Pro Plan
      batch.set(
        _db.collection('plans').doc('pro'),
        {
          'id': 'pro',
          'name': 'Pro',
          'price': 5200,
          'currency': 'KES',
          'billingCycle': 'monthly',
          'maxUsers': -1,
          'features': [
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
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      // Trial Plan (for reference)
      batch.set(
        _db.collection('plans').doc('trial'),
        {
          'id': 'trial',
          'name': 'Trial',
          'price': 0,
          'currency': 'KES',
          'billingCycle': 'once',
          'maxUsers': -1,
          'features': [
            'inventory',
            'sales',
            'expenses',
            'reports',
            'customers',
            'suppliers',
          ],
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if plans already exist
  static Future<bool> plansExist() async {
    try {
      final snapshot = await _db.collection('plans').limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get count of existing plans
  static Future<int> getPlanCount() async {
    try {
      final snapshot = await _db.collection('plans').get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Delete all plans (use with caution!)
  static Future<bool> deleteAllPlans() async {
    try {
      final snapshot = await _db.collection('plans').get();
      final batch = _db.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }
}