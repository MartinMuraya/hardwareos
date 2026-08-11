class HrSettings {
  final double payeRate;
  final double nhifRate;
  final double nssfRate;
  final double housingLevyRate;
  final String commissionBasis;

  HrSettings({
    this.payeRate = 30.0,
    this.nhifRate = 2.75,
    this.nssfRate = 6.0,
    this.housingLevyRate = 1.5,
    this.commissionBasis = 'revenue',
  });

  factory HrSettings.fromMap(Map<String, dynamic> map) {
    return HrSettings(
      payeRate: (map['payeRate'] ?? 30.0).toDouble(),
      nhifRate: (map['nhifRate'] ?? 2.75).toDouble(),
      nssfRate: (map['nssfRate'] ?? 6.0).toDouble(),
      housingLevyRate: (map['housingLevyRate'] ?? 1.5).toDouble(),
      commissionBasis: map['commissionBasis'] ?? 'revenue',
    );
  }
}

class EmployeeModel {
  final String id;
  final String fullName;
  final String role;
  final String kraPin;
  final String nhifNumber;
  final String nssfNumber;
  final double baseSalary;
  final String employmentType;
  final String status;

  EmployeeModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.kraPin,
    required this.nhifNumber,
    required this.nssfNumber,
    required this.baseSalary,
    required this.employmentType,
    required this.status,
  });

  factory EmployeeModel.fromMap(Map<String, dynamic> map, String id) {
    return EmployeeModel(
      id: id,
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? '',
      kraPin: map['kraPin'] ?? '',
      nhifNumber: map['nhifNumber'] ?? '',
      nssfNumber: map['nssfNumber'] ?? '',
      baseSalary: (map['baseSalary'] ?? 0).toDouble(),
      employmentType: map['employmentType'] ?? 'Full-Time',
      status: map['status'] ?? 'Active',
    );
  }
}

class TimesheetModel {
  final String id;
  final String employeeId;
  final String date;
  final double hoursWorked;
  final double overtimeHours;
  final String status;

  TimesheetModel({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.hoursWorked,
    required this.overtimeHours,
    required this.status,
  });

  factory TimesheetModel.fromMap(Map<String, dynamic> map, String id) {
    return TimesheetModel(
      id: id,
      employeeId: map['employeeId'] ?? '',
      date: map['date'] ?? '',
      hoursWorked: (map['hoursWorked'] ?? 0).toDouble(),
      overtimeHours: (map['overtimeHours'] ?? 0).toDouble(),
      status: map['status'] ?? 'Pending',
    );
  }
}

class PayrollModel {
  final String id;
  final String period;
  final double totalGross;
  final double totalDeductions;
  final double totalNetPay;
  final String status;

  PayrollModel({
    required this.id,
    required this.period,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNetPay,
    required this.status,
  });

  factory PayrollModel.fromMap(Map<String, dynamic> map, String id) {
    return PayrollModel(
      id: id,
      period: map['period'] ?? '',
      totalGross: (map['totalGross'] ?? 0).toDouble(),
      totalDeductions: (map['totalDeductions'] ?? 0).toDouble(),
      totalNetPay: (map['totalNetPay'] ?? 0).toDouble(),
      status: map['status'] ?? 'Draft',
    );
  }
}
