import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../models/inventory_ledger_entry.dart';

class ProductLedgerScreen extends StatelessWidget {
  final String productId;
  final String productName;
  final String businessId;

  const ProductLedgerScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.businessId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ledger: $productName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory_ledger')
            .where('businessId', isEqualTo: businessId)
            .where('productId', isEqualTo: productId)
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No ledger entries found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              // Firebase timestamp to ISO string for the model
              if (data['timestamp'] is Timestamp) {
                data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
              }
              
              final entry = InventoryLedgerEntry.fromMap(data);

              final isPositive = entry.quantity > 0;
              final qtyColor = isPositive ? AppColors.success : AppColors.error;
              final qtyPrefix = isPositive ? '+' : '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getColorForType(entry.movementType).withValues(alpha: 0.2),
                    child: Icon(_getIconForType(entry.movementType), color: _getColorForType(entry.movementType)),
                  ),
                  title: Text(
                    entry.movementType,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('MMM d, y, h:mm a').format(entry.timestamp)),
                      if (entry.reason != null && entry.reason!.isNotEmpty)
                        Text('Reason: ${entry.reason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                      Text('Ref: ${entry.referenceId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: Text(
                    '$qtyPrefix${entry.quantity}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: qtyColor),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'SALE': return AppColors.error;
      case 'PURCHASE': return AppColors.success;
      case 'RETURN': return Colors.blue;
      case 'ADJUSTMENT': return Colors.orange;
      case 'OPENING_BALANCE': return Colors.purple;
      case 'TRANSFER_IN': return AppColors.success;
      case 'TRANSFER_OUT': return AppColors.error;
      default: return Colors.grey;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'SALE': return Icons.shopping_cart_checkout;
      case 'PURCHASE': return Icons.local_shipping;
      case 'RETURN': return Icons.assignment_return;
      case 'ADJUSTMENT': return Icons.edit_note;
      case 'OPENING_BALANCE': return Icons.account_balance_wallet;
      case 'TRANSFER_IN': return Icons.input;
      case 'TRANSFER_OUT': return Icons.output;
      default: return Icons.compare_arrows;
    }
  }
}
