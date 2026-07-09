import 'package:biomed_serv/models/device.dart';
import 'package:biomed_serv/models/expense.dart';
import 'package:biomed_serv/providers/device_provider.dart';
import 'package:biomed_serv/providers/expense_provider.dart';
import 'package:biomed_serv/providers/maintenance_form_provider.dart';
import 'package:biomed_serv/providers/service_form_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

/// Yıl-Ay tuple için yardımcı sınıf
class YearMonth {
  final int year;
  final int month;

  YearMonth(this.year, this.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}

class DashboardProvider with ChangeNotifier {
  final ServiceFormProvider _serviceFormProvider;
  final MaintenanceFormProvider _maintenanceFormProvider;
  final DeviceProvider _deviceProvider;
  final ExpenseProvider _expenseProvider;

  Map<YearMonth, int> _monthlyServiceCounts = {};
  Map<YearMonth, int> get monthlyServiceCounts => _monthlyServiceCounts;

  Map<YearMonth, int> _monthlyMaintenanceCounts = {};
  Map<YearMonth, int> get monthlyMaintenanceCounts => _monthlyMaintenanceCounts;

  int _totalServices = 0;
  int get totalServices => _totalServices;

  int _totalMaintenances = 0;
  int get totalMaintenances => _totalMaintenances;

  // 🆕 Cihaz Metrikleri
  int _totalDevices = 0;
  int get totalDevices => _totalDevices;

  int _totalCustomers = 0;
  int get totalCustomers => _totalCustomers;

  Map<OwnershipStatus, int> _ownershipDistribution = {};
  Map<OwnershipStatus, int> get ownershipDistribution => _ownershipDistribution;

  // 🆕 Masraf Metrikleri
  double _totalCollectedAmount = 0;
  double get totalCollectedAmount => _totalCollectedAmount;

  int _pendingExpenseCount = 0;
  int get pendingExpenseCount => _pendingExpenseCount;

  DashboardProvider(
    this._serviceFormProvider,
    this._maintenanceFormProvider,
    this._deviceProvider,
    this._expenseProvider,
  ) {
    // Provider'lardaki değişiklikleri dinle
    _serviceFormProvider.addListener(_calculateMetrics);
    _maintenanceFormProvider.addListener(_calculateMetrics);
    _deviceProvider.addListener(_calculateMetrics);
    _expenseProvider.addListener(_calculateMetrics);
    // Başlangıçta metrikleri hesapla
    _calculateMetrics();
  }

  void _calculateMetrics() {
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

    // SERVİS FORMLARI
    final recentServices = _serviceFormProvider.forms.where((form) {
      return form.createdAt.isAfter(sixMonthsAgo);
    }).toList();

    // Yıl-Ay olarak grupla (doğru yıl kontrolü)
    final groupedServices = groupBy(
      recentServices,
      (form) => YearMonth(form.createdAt.year, form.createdAt.month),
    );

    // BAKIM FORMLARI
    final recentMaintenances = _maintenanceFormProvider.forms.where((form) {
      return form.createdAt.isAfter(sixMonthsAgo);
    }).toList();

    final groupedMaintenances = groupBy(
      recentMaintenances,
      (form) => YearMonth(form.createdAt.year, form.createdAt.month),
    );

    // Son 6 ayı doldur
    final serviceCounts = <YearMonth, int>{};
    final maintenanceCounts = <YearMonth, int>{};

    for (int i = 0; i < 6; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final yearMonth = YearMonth(date.year, date.month);

      serviceCounts[yearMonth] = groupedServices[yearMonth]?.length ?? 0;
      maintenanceCounts[yearMonth] = groupedMaintenances[yearMonth]?.length ?? 0;
    }

    _monthlyServiceCounts = serviceCounts;
    _monthlyMaintenanceCounts = maintenanceCounts;
    _totalServices = _serviceFormProvider.forms.length;
    _totalMaintenances = _maintenanceFormProvider.forms.length;

    // 🆕 CİHAZ METRİKLERİ
    _totalDevices = _deviceProvider.devices.length;
    
    // Sahiplik dağılımı (SOLD/RENT)
    final ownershipMap = <OwnershipStatus, int>{};
    for (final device in _deviceProvider.devices) {
      ownershipMap[device.ownershipStatus] = (ownershipMap[device.ownershipStatus] ?? 0) + 1;
    }
    _ownershipDistribution = ownershipMap;

    // 🆕 MASRAF METRİKLERİ
    _totalCollectedAmount = _expenseProvider.totalCollectedAmount;
    _pendingExpenseCount = _expenseProvider.pendingExpenses.length;

    notifyListeners();
  }

  @override
  void dispose() {
    _serviceFormProvider.removeListener(_calculateMetrics);
    _maintenanceFormProvider.removeListener(_calculateMetrics);
    _deviceProvider.removeListener(_calculateMetrics);
    _expenseProvider.removeListener(_calculateMetrics);
    super.dispose();
  }
}
