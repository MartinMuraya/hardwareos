import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accounting_provider.dart';

class AccountingDashboardScreen extends StatefulWidget {
  const AccountingDashboardScreen({super.key});

  @override
  State<AccountingDashboardScreen> createState() => _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState extends State<AccountingDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AccountingProvider>();
      if (provider.accounts.isEmpty) provider.fetchAccounts();
      if (provider.trialBalance == null) provider.fetchTrialBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('General Ledger'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Trial Balance & P&L'),
              Tab(text: 'Chart of Accounts'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Refresh',
              onPressed: () {
                context.read<AccountingProvider>().fetchAccounts();
                context.read<AccountingProvider>().fetchTrialBalance();
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _TrialBalanceTab(),
            _ChartOfAccountsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // TODO: Manual Journal Entry dialog
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manual entries coming soon!')));
          },
          icon: const Icon(Icons.add),
          label: const Text('Journal Entry'),
        ),
      ),
    );
  }
}

class _TrialBalanceTab extends StatelessWidget {
  const _TrialBalanceTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountingProvider>();

    if (provider.isLoading && provider.trialBalance == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)));
    }

    final tb = provider.trialBalance;
    if (tb == null || tb.accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No ledger data found.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await provider.migrateHistoricalData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Historical data migrated to ledger!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Migration failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Migrate Historical Data'),
            )
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
          columns: const [
            DataColumn(label: Text('Account', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Debit', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('Credit', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          ],
          rows: [
            ...tb.accounts.map((acc) => DataRow(
              cells: [
                DataCell(Text('${acc.code} - ${acc.name}')),
                DataCell(Text(acc.type)),
                DataCell(Text(acc.debit > 0 ? acc.debit.toStringAsFixed(2) : '-')),
                DataCell(Text(acc.credit > 0 ? acc.credit.toStringAsFixed(2) : '-')),
                DataCell(Text(acc.balance.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
              ],
            )).toList(),
            DataRow(
              color: MaterialStateProperty.all(Colors.green[50]),
              cells: [
                const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
                DataCell(Text(tb.totalDebits.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(tb.totalCredits.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartOfAccountsTab extends StatelessWidget {
  const _ChartOfAccountsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountingProvider>();

    if (provider.isLoading && provider.accounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.accounts.isEmpty) {
      return Center(
        child: ElevatedButton(
          onPressed: () => provider.initializeAccounts(),
          child: const Text('Initialize Standard Chart of Accounts'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.accounts.length,
      itemBuilder: (context, index) {
        final acc = provider.accounts[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getColor(acc.type),
              child: Text(acc.type[0], style: const TextStyle(color: Colors.white)),
            ),
            title: Text('${acc.code} - ${acc.name}'),
            subtitle: Text(acc.type),
          ),
        );
      },
    );
  }

  Color _getColor(String type) {
    switch (type) {
      case 'Asset': return Colors.blue;
      case 'Liability': return Colors.red;
      case 'Equity': return Colors.purple;
      case 'Revenue': return Colors.green;
      case 'Expense': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
