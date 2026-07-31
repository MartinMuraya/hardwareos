import 'package:flutter/material.dart';
import '../../../core/services/functions_service.dart';
import '../models/accounting_models.dart';

class AccountingProvider extends ChangeNotifier {
  final String businessId;

  bool _isLoading = false;
  String? _error;
  List<AccountModel> _accounts = [];
  TrialBalance? _trialBalance;
  ProfitAndLoss? _profitAndLoss;
  BalanceSheet? _balanceSheet;

  AccountingProvider({required this.businessId}) {
    // Only fetch if we have a real businessId — avoids firing on startup
    // with empty string before auth is loaded
    if (businessId.isNotEmpty) {
      fetchAccounts();
    }
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AccountModel> get accounts => _accounts;
  TrialBalance? get trialBalance => _trialBalance;
  ProfitAndLoss? get profitAndLoss => _profitAndLoss;
  BalanceSheet? get balanceSheet => _balanceSheet;

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
    // Guard: don't call the function with no businessId
    if (businessId.isEmpty) return;
    _setLoading(true);
    try {
      final res = await FunctionsService.call('getChartOfAccounts', {
        'businessId': businessId,
      });
      final List accs = res['accounts'] ?? [];
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
      _trialBalance = TrialBalance.fromMap(res);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> fetchProfitAndLoss({String? startDate, String? endDate}) async {
    _setLoading(true);
    try {
      final res = await FunctionsService.call('getProfitAndLoss', {
        'businessId': businessId,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      });
      _profitAndLoss = ProfitAndLoss.fromMap(res);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> fetchBalanceSheet({String? asOfDate}) async {
    _setLoading(true);
    try {
      final res = await FunctionsService.call('getBalanceSheet', {
        'businessId': businessId,
        if (asOfDate != null) 'asOfDate': asOfDate,
      });
      _balanceSheet = BalanceSheet.fromMap(res);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> postManualJournal(
      String description, List<Map<String, dynamic>> lines) async {
    _setLoading(true);
    try {
      await FunctionsService.call('createJournalEntry', {
        'businessId': businessId,
        'description': description,
        'lines': lines,
      });
      await fetchTrialBalance();
      await fetchProfitAndLoss();
      await fetchBalanceSheet();
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
