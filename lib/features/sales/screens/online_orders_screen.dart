import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';

class OnlineOrdersScreen extends StatefulWidget {
  const OnlineOrdersScreen({super.key});

  @override
  State<OnlineOrdersScreen> createState() => _OnlineOrdersScreenState();
}

class _OnlineOrdersScreenState extends State<OnlineOrdersScreen> {
  Future<void> _handleAction(String orderId, String action) async {
    final auth = context.read<AuthProvider>();
    if (auth.businessId == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final funcName =
          action == 'approve' ? 'approveOnlineOrder' : 'rejectOnlineOrder';
      await FunctionsService.call(funcName, {
        'businessId': auth.businessId,
        'orderId': orderId,
      });

      if (mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order ${action}d successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final businessId = auth.businessId;

    if (businessId == null) {
      return const Scaffold(body: Center(child: Text('No business selected')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Orders'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('online_orders')
            .where('businessId', isEqualTo: businessId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No online orders found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final orderId = docs[index].id;
              final status = data['status'] as String? ?? 'unknown';
              final items = data['items'] as List<dynamic>? ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Order #${orderId.substring(0, 8).toUpperCase()}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Chip(
                            label: Text(status.toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            backgroundColor: status == 'pending'
                                ? Colors.orange
                                : (status == 'approved'
                                    ? Colors.green
                                    : Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Customer: ${data['customerName']} (${data['customerPhone']})'),
                      Text('Address: ${data['address']}'),
                      if (data['note'] != null &&
                          data['note'].toString().isNotEmpty)
                        Text('Note: ${data['note']}',
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                      const Divider(),
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                    child: Text(
                                        '${item['quantity']}x ${item['name']}')),
                                Text(
                                    '\$${(item['sellingPrice'] * item['quantity']).toStringAsFixed(2)}'),
                              ],
                            ),
                          )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('\$${(data['total'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.green)),
                        ],
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _handleAction(orderId, 'reject'),
                              child: const Text('Reject',
                                  style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green),
                              onPressed: () =>
                                  _handleAction(orderId, 'approve'),
                              child: const Text('Approve & Create Sale'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
