import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user.dart' as app_user;
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import 'package:intl/intl.dart';

class StaffCommissionsTab extends StatefulWidget {
  const StaffCommissionsTab({super.key});

  @override
  State<StaffCommissionsTab> createState() => _StaffCommissionsTabState();
}

class _StaffCommissionsTabState extends State<StaffCommissionsTab> {
  final _currencyFormat = NumberFormat.currency(symbol: 'KES ');
  bool _isPayingOut = false;

  Future<void> _payout(
      BuildContext context, String targetUserId, double amount) async {
    final bizId = context.read<AuthProvider>().businessId!;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Payout'),
        content: Text(
            'Are you sure you want to payout ${_currencyFormat.format(amount)} to this user?\n\nThis will zero their balance and create an Expense record.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Payout')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPayingOut = true);
    try {
      await FunctionsService.call('payoutCommission', {
        'businessId': bizId,
        'targetUserId': targetUserId,
        'amount': amount,
      });
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Payout successful! Expense recorded.')));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isPayingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bizId = context.watch<AuthProvider>().businessId;
    if (bizId == null) return const SizedBox.shrink();

    return Column(
      children: [
        if (_isPayingOut) const LinearProgressIndicator(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('businessId', isEqualTo: bizId)
                .where('commissionBalance', isGreaterThan: 0)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                    child: Text('No outstanding commissions to pay.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final user = app_user.User.fromMap(data);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?'),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(
                          'Rate: ${((user.commissionRate ?? 0) * 100).toStringAsFixed(1)}%'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currencyFormat.format(user.commissionBalance ?? 0),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isPayingOut
                                ? null
                                : () => _payout(context, user.uid,
                                    user.commissionBalance ?? 0),
                            child: const Text('Payout'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
