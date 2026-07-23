import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/functions_service.dart';
import '../models/hr_models.dart';

class HrProvider extends ChangeNotifier {
  final String businessId;

  bool _isLoading = false;
  String? _error;
  HrSettings? _settings;

  HrProvider({required this.businessId}) {
    fetchSettings();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  HrSettings? get settings => _settings;

  Future<void> fetchSettings() async {
    _setLoading(true);
    try {
      final res = await FunctionsService.call('getHrSettings', {'businessId': businessId});
      _settings = HrSettings.fromMap(res.data);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> saveSettings(double paye, double nhif, double nssf) async {
    _setLoading(true);
    try {
      await FunctionsService.call('saveHrSettings', {
        'businessId': businessId,
        'payeRate': paye,
        'nhifRate': nhif,
        'nssfRate': nssf,
      });
      await fetchSettings();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createEmployee(Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      await FunctionsService.call('createEmployee', {
        'businessId': businessId,
        ...data,
      });
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> generatePayroll(String period) async {
    _setLoading(true);
    try {
      await FunctionsService.call('generatePayroll', {
        'businessId': businessId,
        'period': period,
      });
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> processPayroll(String payrollId) async {
    _setLoading(true);
    try {
      await FunctionsService.call('processPayroll', {
        'businessId': businessId,
        'payrollId': payrollId,
      });
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // Streams for UI
  Stream<List<EmployeeModel>> getEmployeesStream() {
    return FirebaseFirestore.instance
        .collection('employees')
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => EmployeeModel.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<PayrollModel>> getPayrollsStream() {
    return FirebaseFirestore.instance
        .collection('payrolls')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PayrollModel.fromMap(d.data(), d.id)).toList());
  }
}
