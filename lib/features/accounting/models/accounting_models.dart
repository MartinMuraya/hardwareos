class AccountModel {
  final String id;
  final String code;
  final String name;
  final String type;

  AccountModel({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
  });

  factory AccountModel.fromMap(Map<String, dynamic> map, String id) {
    return AccountModel(
      id: id,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? '',
    );
  }
}

class TrialBalanceAccount {
  final String id;
  final String code;
  final String name;
  final String type;
  final double debit;
  final double credit;
  final double balance;

  TrialBalanceAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory TrialBalanceAccount.fromMap(Map<String, dynamic> map) {
    return TrialBalanceAccount(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? '',
      debit: (map['debit'] ?? 0).toDouble(),
      credit: (map['credit'] ?? 0).toDouble(),
      balance: (map['balance'] ?? 0).toDouble(),
    );
  }
}

class TrialBalance {
  final List<TrialBalanceAccount> accounts;
  final double totalDebits;
  final double totalCredits;

  TrialBalance({
    required this.accounts,
    required this.totalDebits,
    required this.totalCredits,
  });

  factory TrialBalance.fromMap(Map<String, dynamic> map) {
    final accs = (map['accounts'] as List?)?.map((e) => TrialBalanceAccount.fromMap(e as Map<String, dynamic>)).toList() ?? [];
    return TrialBalance(
      accounts: accs,
      totalDebits: (map['totalDebits'] ?? 0).toDouble(),
      totalCredits: (map['totalCredits'] ?? 0).toDouble(),
    );
  }
}

class ProfitAndLoss {
  final List<Map<String, dynamic>> revenue;
  final List<Map<String, dynamic>> expenses;
  final double totalRevenue;
  final double totalExpense;
  final double netProfit;

  ProfitAndLoss({
    required this.revenue,
    required this.expenses,
    required this.totalRevenue,
    required this.totalExpense,
    required this.netProfit,
  });

  factory ProfitAndLoss.fromMap(Map<String, dynamic> map) {
    return ProfitAndLoss(
      revenue: List<Map<String, dynamic>>.from(map['revenue'] ?? []),
      expenses: List<Map<String, dynamic>>.from(map['expenses'] ?? []),
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      totalExpense: (map['totalExpense'] ?? 0).toDouble(),
      netProfit: (map['netProfit'] ?? 0).toDouble(),
    );
  }
}

class BalanceSheet {
  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> liabilities;
  final List<Map<String, dynamic>> equity;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final bool isBalanced;

  BalanceSheet({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.isBalanced,
  });

  factory BalanceSheet.fromMap(Map<String, dynamic> map) {
    return BalanceSheet(
      assets: List<Map<String, dynamic>>.from(map['assets'] ?? []),
      liabilities: List<Map<String, dynamic>>.from(map['liabilities'] ?? []),
      equity: List<Map<String, dynamic>>.from(map['equity'] ?? []),
      totalAssets: (map['totalAssets'] ?? 0).toDouble(),
      totalLiabilities: (map['totalLiabilities'] ?? 0).toDouble(),
      totalEquity: (map['totalEquity'] ?? 0).toDouble(),
      isBalanced: map['isBalanced'] ?? false,
    );
  }
}
