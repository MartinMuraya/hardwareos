import 'package:flutter/material.dart';

import 'employee_directory_tab.dart';
import 'hr_settings_tab.dart';
import 'payroll_tab.dart';
import 'staff_commissions_tab.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({super.key});

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HR & Payroll'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Employees'),
              Tab(text: 'Payroll'),
              Tab(text: 'Commissions'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EmployeeDirectoryTab(),
            PayrollTab(),
            StaffCommissionsTab(),
            HrSettingsTab(),
          ],
        ),
      ),
    );
  }
}
