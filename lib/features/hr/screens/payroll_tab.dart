import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/hr_provider.dart';
import '../models/hr_models.dart';

class PayrollTab extends StatelessWidget {
  const PayrollTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HrProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payroll Runs',
                  style: Theme.of(context).textTheme.headlineSmall),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white),
                onPressed: () => _generatePayroll(context, provider),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Generate Payroll'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PayrollModel>>(
            stream: provider.getPayrollsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final payrolls = snapshot.data ?? [];
              if (payrolls.isEmpty) {
                return const Center(child: Text('No payrolls generated yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payrolls.length,
                itemBuilder: (context, index) {
                  final pr = payrolls[index];
                  final isDraft = pr.status == 'Draft';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Period: ${pr.period}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              Chip(
                                label: Text(pr.status,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                backgroundColor:
                                    isDraft ? Colors.orange : Colors.green,
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Gross:'),
                              Text('KES ${pr.totalGross.toStringAsFixed(2)}'),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Deductions (PAYE/NHIF/NSSF):'),
                              Text(
                                  'KES ${pr.totalDeductions.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Net Pay:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text('KES ${pr.totalNetPay.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.green)),
                            ],
                          ),
                          if (isDraft) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white),
                                onPressed: provider.isLoading
                                    ? null
                                    : () async {
                                        try {
                                          await provider.processPayroll(pr.id);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Payroll Processed & Ledger Updated!')));
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content:
                                                        Text('Error: $e')));
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Process & Post to Ledger'),
                              ),
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
        ),
      ],
    );
  }

  void _generatePayroll(BuildContext context, HrProvider provider) async {
    final currentPeriod = DateFormat('MMMM yyyy').format(DateTime.now());
    try {
      await provider.generatePayroll(currentPeriod);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Draft Payroll for $currentPeriod generated!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
