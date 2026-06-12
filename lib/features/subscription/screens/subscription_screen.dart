import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/business.dart';
import '../../../core/models/subscription.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/services/feature_access_service.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/plan_card.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _selectedPlanId;
  String _phoneNumber = '';
  bool _isProcessing = false;
  String? _error;
  List<Subscription> _paymentHistory = [];
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    final businessProvider = Provider.of<BusinessProvider>(context, listen: false);
    final businessId = businessProvider.businessId;

    if (businessId == null) return;

    setState(() => _loadingHistory = true);
    try {
      final res = await FunctionsService.call('getMySubscriptionPayments', {});
      final payments = (res['payments'] as List? ?? [])
          .map((s) => Subscription.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _paymentHistory = payments;
          _loadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final businessProvider = Provider.of<BusinessProvider>(context);
    final authProvider = context.read<AuthProvider>();
    Map<String, dynamic>? businessData = businessProvider.businessData;

    // If business data not loaded, try to use auth provider's business data
    if (businessData == null) {
      final userProfile = authProvider.userProfile;
      final businessId = authProvider.businessId;
      // Only build fallback if we have a businessId to avoid null crash
      if (userProfile != null && businessId != null && businessId.isNotEmpty) {
        businessData = {
          'id': businessId,
          'name': 'My Business', // will be updated once businessProvider loads
          'plan': userProfile['plan'] as String? ?? 'trial',
          'subscriptionStatus': userProfile['subscriptionStatus'] as String? ?? 'trial',
          'trialEndsAt': userProfile['trialEndsAt'],
          'subscriptionStartsAt': userProfile['subscriptionStartsAt'],
          'subscriptionEndsAt': userProfile['subscriptionEndsAt'],
          'ownerId': authProvider.user?.uid ?? '',
          'createdAt': DateTime.now().toIso8601String(),
          'active': true,
        };
      }
    }

    if (businessData == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading subscription data...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    // Safely build Business model, ensuring no null required fields
    final safeData = Map<String, dynamic>.from(businessData);
    safeData['id'] = (safeData['id'] as String?) ?? '';
    safeData['name'] = (safeData['name'] as String?) ?? 'My Business';
    safeData['plan'] = (safeData['plan'] as String?) ?? 'trial';
    safeData['subscriptionStatus'] = (safeData['subscriptionStatus'] as String?) ?? 'trial';
    safeData['ownerId'] = (safeData['ownerId'] as String?) ?? '';

    final business = Business.fromMap(safeData);
    final isExpired = business.isExpired;
    final isOnTrial = business.isOnTrial;
    final isActive = business.isActive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Subscription & Plans', style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCurrentStatusCard(business, isExpired, isOnTrial, isActive),
            const SizedBox(height: 24),
            _buildAvailablePlansSection(),
            if (_selectedPlanId != null) ...[
              const SizedBox(height: 24),
              _buildPaymentSection(business),
            ],
            const SizedBox(height: 24),
            _buildPaymentHistorySection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(Business business, bool isExpired, bool isOnTrial, bool isActive) {
    final statusColor = isExpired ? AppColors.error : (isActive ? AppColors.success : AppColors.warning);
    final statusText = isExpired ? 'Expired' : (isActive ? 'Active' : 'Trial');
    final expiryDate = isOnTrial ? business.trialEndsAt : business.subscriptionEndsAt;
    final daysLeft = isOnTrial ? business.trialDaysLeft : business.subscriptionDaysLeft;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Plan', style: AppTheme.darkTheme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.plan.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.accent),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              if (daysLeft != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$daysLeft days left',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Expires: ${expiryDate?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
          if (isExpired)
            Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_rounded, color: AppColors.error, size: 18),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your trial or subscription has expired. Upgrade to continue using HardwareOS.',
                          style: TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAvailablePlansSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Plans', style: AppTheme.darkTheme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PlanCard(
                  planId: 'starter',
                  name: 'Starter',
                  price: 'KES 2,600',
                  billing: '/month',
                  features: FeatureAccessService.getFeatures('starter'),
                  isSelected: _selectedPlanId == 'starter',
                  onSelect: () => setState(() => _selectedPlanId = 'starter'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PlanCard(
                  planId: 'pro',
                  name: 'Pro',
                  price: 'KES 5,200',
                  billing: '/month',
                  features: FeatureAccessService.getFeatures('pro'),
                  isSelected: _selectedPlanId == 'pro',
                  onSelect: () => setState(() => _selectedPlanId = 'pro'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(Business business) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Details', style: AppTheme.darkTheme.textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) => setState(() => _phoneNumber = val),
            decoration: InputDecoration(
              hintText: '254712345678',
              labelText: 'M-Pesa Phone Number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isProcessing || _phoneNumber.isEmpty || _selectedPlanId == null
                  ? null
                  : () => _processPayment(business.id),
              child: _isProcessing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Pay with M-Pesa STK Push'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPayment(String businessId) async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await FunctionsService.call('createSubscriptionPayment', {
        'businessId': businessId,
        'planId': _selectedPlanId,
        'phoneNumber': _phoneNumber,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('STK Push sent! Please enter your M-Pesa PIN on your phone to complete payment.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 8),
          ),
        );
        setState(() => _isProcessing = false);

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  Widget _buildPaymentHistorySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment History', style: AppTheme.darkTheme.textTheme.titleMedium),
          const SizedBox(height: 16),
          if (_loadingHistory)
            const Center(child: CircularProgressIndicator())
          else if (_paymentHistory.isEmpty)
            const EmptyState(
              icon: Icons.receipt_rounded,
              title: 'No Payment History',
              subtitle: 'Your payments will appear here',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paymentHistory.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _buildPaymentHistoryItem(_paymentHistory[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryItem(Subscription sub) {
    final statusColor = sub.isCompleted ? AppColors.success : (sub.isFailed ? AppColors.error : AppColors.warning);
    final statusText = sub.isCompleted ? 'Completed' : (sub.isFailed ? 'Failed' : 'Pending');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_rounded, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.plan.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${sub.createdAt.toLocal().toString().split(' ')[0]} • KES ${sub.amount}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
          ),
        ],
      ),
    );
  }
}
