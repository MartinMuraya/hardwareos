import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hr_provider.dart';
import '../models/hr_models.dart';

class EmployeeDirectoryTab extends StatelessWidget {
  const EmployeeDirectoryTab({super.key});

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
              Text('Employee Directory',
                  style: Theme.of(context).textTheme.headlineSmall),
              ElevatedButton.icon(
                onPressed: () => _showAddEmployeeDialog(context, provider),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Employee'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<EmployeeModel>>(
            stream: provider.getEmployeesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final employees = snapshot.data ?? [];
              if (employees.isEmpty) {
                return const Center(
                    child: Text(
                        'No employees found. Add one to start processing payroll.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final emp = employees[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(emp.fullName[0])),
                      title: Text(emp.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${emp.role} • ${emp.employmentType}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('KES ${emp.baseSalary.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          Text(emp.status,
                              style: TextStyle(
                                  color: emp.status == 'Active'
                                      ? Colors.blue
                                      : Colors.red,
                                  fontSize: 12)),
                        ],
                      ),
                      onTap: () {
                        // View Details
                      },
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

  void _showAddEmployeeDialog(BuildContext context, HrProvider provider) {
    final formKey = GlobalKey<FormState>();
    String fullName = '';
    String role = 'Staff';
    String kraPin = '';
    double baseSalary = 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Employee'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                  onSaved: (val) => fullName = val!,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                      labelText: 'Role (e.g., Cashier, Manager) *'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                  onSaved: (val) => role = val!,
                ),
                TextFormField(
                  decoration: const InputDecoration(
                      labelText: 'Base Salary (Monthly) *'),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                  onSaved: (val) => baseSalary = double.tryParse(val!) ?? 0,
                ),
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'KRA PIN (Optional)'),
                  onSaved: (val) => kraPin = val ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              try {
                await provider.createEmployee({
                  'fullName': fullName,
                  'role': role,
                  'baseSalary': baseSalary,
                  'kraPin': kraPin,
                  'employmentType': 'Full-Time',
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Employee added!')));
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
