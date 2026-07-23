import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hr_provider.dart';
import 'employee_directory_tab.dart';
import 'hr_settings_tab.dart';
import 'payroll_tab.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HR & Payroll'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Employees'),
              Tab(text: 'Payroll'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EmployeeDirectoryTab(),
            PayrollTab(),
            HrSettingsTab(),
          ],
        ),
      ),
    );
  }
}
