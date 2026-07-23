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
