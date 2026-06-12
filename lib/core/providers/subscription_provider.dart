import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plan.dart';
import '../models/subscription.dart';
import '../services/functions_service.dart';

final plansProvider = FutureProvider<List<Plan>>((ref) async {
  final res = await FunctionsService.call('adminGetPlans', {});
  final plans = (res['plans'] as List? ?? [])
      .map((p) => Plan.fromMap(Map<String, dynamic>.from(p as Map)))
      .toList();
  return plans;
});

final subscriptionHistoryProvider =
    FutureProvider.family<List<Subscription>, String>((ref, businessId) async {
  final res = await FunctionsService.call('adminGetSubscriptions', {
    'businessId': businessId,
  });
  final subs = (res['subscriptions'] as List? ?? [])
      .map((s) => Subscription.fromMap(Map<String, dynamic>.from(s as Map)))
      .toList();
  return subs;
});

final createSubscriptionPaymentProvider = FutureProvider.family<
    Map<String, dynamic>,
    ({String businessId, String planId, String phoneNumber})>((ref, args) async {
  return await FunctionsService.call('createSubscriptionPayment', {
    'businessId': args.businessId,
    'planId': args.planId,
    'phoneNumber': args.phoneNumber,
  });
});

final simulateMpesaCallbackProvider = FutureProvider.family<
    Map<String, dynamic>,
    ({String checkoutRequestId, bool success})>((ref, args) async {
  return await FunctionsService.call('simulateMpesaCallback', {
    'checkoutRequestId': args.checkoutRequestId,
    'success': args.success,
  });
});
