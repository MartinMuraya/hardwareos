import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../models/accounting_models.dart';

class AccountingProvider extends ChangeNotifier {
  final String businessId;

  bool _isLoading = false;
  String? _error;
  List<AccountModel> _accounts = [];
  TrialBalance? _trialBalance;

  AccountingProvider({required this.businessId}) {
    fetchAccounts();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AccountModel> get accounts => _accounts;
  TrialBalance? get trialBalance => _trialBalance;

  Future<void> initializeAccounts() async {
    _setLoading(true);
    try {
      await FunctionsService.call('initializeChartOfAccounts', {
        'businessId': businessId,
      });
      await fetchAccounts();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAccounts() async {
    _setLoading(true);
    try {
      final res = await FunctionsService.call('getChartOfAccounts', {
        'businessId': businessId,
      });
      final List accs = res.data['accounts'] ?? [];
      _accounts = accs.map((e) => AccountModel.fromMap(e, e['id'])).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> fetchTrialBalance() async {
    _setLoading(true);
    try {
      final res = await FunctionsService.call('getTrialBalance', {
        'businessId': businessId,
      });
      _trialBalance = TrialBalance.fromMap(res.data);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> postManualJournal(String description, List<Map<String, dynamic>> lines) async {
    _setLoading(true);
    try {
      await FunctionsService.call('postManualJournalEntry', {
        'businessId': businessId,
        'description': description,
        'lines': lines,
      });
      await fetchTrialBalance();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> migrateHistoricalData() async {
    _setLoading(true);
    try {
      await FunctionsService.call('migrateHistoricalData', {
        'businessId': businessId,
      });
      await fetchTrialBalance();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
