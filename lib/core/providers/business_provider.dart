import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';

class BusinessProvider extends ChangeNotifier {
  Map<String, dynamic>? _businessData;
  bool _isLoading = false;

  Map<String, dynamic>? get businessData       => _businessData;
  bool                   get isLoading          => _isLoading;
  String?                get businessId         => _businessData?['id'] as String?;
  String?                get businessName       => _businessData?['name'] as String?;
  String?                get plan               => _businessData?['plan'] as String?;
  String?                get subscriptionStatus => _businessData?['subscriptionStatus'] as String?;

  bool get isOnTrial   => subscriptionStatus == 'trial';
  bool get isExpired   => subscriptionStatus == 'expired';
  bool get isActive    => subscriptionStatus == 'active';
  bool get isPro       => plan == 'pro';
  bool get isStarter   => plan == 'starter' || plan == 'pro';
  bool get isFree      => plan == 'free';

  int? get trialDaysLeft {
    final trialEndsAt = _businessData?['trialEndsAt'];
    if (trialEndsAt == null) return null;
    final endDate = DateTime.tryParse(trialEndsAt.toString());
    if (endDate == null) return null;
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff.clamp(0, 999);
  }

  void updateFromAuth(AuthProvider auth) {
    if (auth.isAuthenticated && auth.isRegistered) {
      // Business data is loaded via getDashboardStats - this syncs plan info
      // It's populated when dashboard loads; here we just reset on sign-out
    } else {
      _businessData = null;
      notifyListeners();
    }
  }

  void setBusinessData(Map<String, dynamic> data) {
    _businessData = data;
    notifyListeners();
  }

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
