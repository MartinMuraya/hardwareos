import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/services/offline_service.dart';
import '../../../core/providers/auth_provider.dart';

enum SyncStatus { idle, syncing, error }

class OfflineSalesQueue extends ChangeNotifier {
  SyncStatus _status = SyncStatus.idle;
  int _pendingSales = 0;
  int _pendingPayments = 0;
  int _pendingInventory = 0;
  String? _lastError;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  SyncStatus get status => _status;
  int get pendingSales => _pendingSales;
  int get pendingPayments => _pendingPayments;
  int get pendingInventory => _pendingInventory;
  int get totalPending => _pendingSales + _pendingPayments + _pendingInventory;
  String? get lastError => _lastError;
  bool get isSyncing => _status == SyncStatus.syncing;

  void refresh() {
    _pendingSales = OfflineService.pendingSaleCount;
    _pendingPayments = OfflineService.pendingPaymentCount;
    _pendingInventory = OfflineService.pendingInventoryCount;
    notifyListeners();
  }

  Future<void> enqueueOfflineSale(Map<String, dynamic> saleData) async {
    final sale = PendingSale(
      id: 'offline_${const Uuid().v4()}',
      saleData: saleData,
      createdAt: DateTime.now(),
    );
    await OfflineService.enqueueSale(sale);
    refresh();
  }

  Future<void> enqueueOfflinePayment(Map<String, dynamic> paymentData) async {
    final payment = PendingPayment(
      id: 'pmt_${const Uuid().v4()}',
      paymentData: paymentData,
      createdAt: DateTime.now(),
    );
    await OfflineService.enqueuePayment(payment);
    refresh();
  }

  Future<void> enqueueOfflineInventoryUpdate(Map<String, dynamic> updateData) async {
    final update = PendingInventoryUpdate(
      id: 'inv_${const Uuid().v4()}',
      updateData: updateData,
      createdAt: DateTime.now(),
    );
    await OfflineService.enqueueInventoryUpdate(update);
    refresh();
  }

  Future<void> syncAll(BuildContext context) async {
    if (_status == SyncStatus.syncing) return;
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      await _syncSales(context);
      await _syncPayments(context);
      await _syncInventory(context);
      _status = SyncStatus.idle;
      _retryAttempt = 0;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      _scheduleRetry(context);
    }
    refresh();
  }

  Future<void> _syncSales(BuildContext context) async {
    final sales = OfflineService.getPendingSales();
    final auth = context.read<AuthProvider>();
    final bizId = auth.businessId;

    for (final sale in sales) {
      try {
        if (bizId == null) continue;
        sale.saleData['businessId'] = bizId;
        await FunctionsService.call('createSale', sale.saleData);
        await OfflineService.removeSale(sale.id);
      } on FunctionsException catch (e) {
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          sale.retryCount++;
          await OfflineService.enqueueSale(sale);
          await OfflineService.removeSale(sale.id);
          throw e;
        }
        await OfflineService.removeSale(sale.id);
      }
    }
  }

  Future<void> _syncPayments(BuildContext context) async {
    final payments = OfflineService.getPendingPayments();
    final auth = context.read<AuthProvider>();
    final bizId = auth.businessId;

    for (final payment in payments) {
      try {
        if (bizId == null) continue;
        payment.paymentData['businessId'] = bizId;
        await FunctionsService.call('recordDebtPayment', payment.paymentData);
        await OfflineService.removePayment(payment.id);
      } on FunctionsException catch (e) {
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          payment.retryCount++;
          await OfflineService.enqueuePayment(payment);
          await OfflineService.removePayment(payment.id);
          throw e;
        }
        await OfflineService.removePayment(payment.id);
      }
    }
  }

  Future<void> _syncInventory(BuildContext context) async {
    final updates = OfflineService.getPendingInventoryUpdates();
    final auth = context.read<AuthProvider>();
    final bizId = auth.businessId;

    for (final update in updates) {
      try {
        if (bizId == null) continue;
        update.updateData['businessId'] = bizId;
        await FunctionsService.call('addStock', update.updateData);
        await OfflineService.removeInventoryUpdate(update.id);
      } on FunctionsException catch (e) {
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          update.retryCount++;
          await OfflineService.enqueueInventoryUpdate(update);
          await OfflineService.removeInventoryUpdate(update.id);
          throw e;
        }
        await OfflineService.removeInventoryUpdate(update.id);
      }
    }
  }

  void _scheduleRetry(BuildContext context) {
    _retryTimer?.cancel();
    final delays = [10, 30, 60];
    final delay = _retryAttempt < delays.length
        ? delays[_retryAttempt]
        : delays.last;
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: delay), () {
      syncAll(context);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
