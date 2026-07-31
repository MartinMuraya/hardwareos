import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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

  List<PendingSale> get pendingSalesList => OfflineService.getPendingSales();

  Future<void> removeSale(String id) async {
    await OfflineService.removeSale(id);
    refresh();
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

  Future<void> syncAll(AuthProvider auth) async {
    if (_status == SyncStatus.syncing) return;
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      await _syncSales(auth);
      await _syncPayments(auth);
      await _syncInventory(auth);
      _status = SyncStatus.idle;
      _retryAttempt = 0;
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
      _scheduleRetry(auth);
    }
    refresh();
  }

  int get conflictedSalesCount => OfflineService.conflictedSaleCount;
  List<ConflictedSale> get conflictedSalesList => OfflineService.getConflictedSales();

  Future<void> removeConflictedSale(String id) async {
    await OfflineService.removeConflictedSale(id);
    refresh();
  }

  static const int _maxRetries = 10;
  static const int _maxAgeDays = 7;

  Future<void> _syncSales(AuthProvider auth) async {
    final sales = OfflineService.getPendingSales();
    final bizId = auth.businessId;

    for (final sale in sales) {
      if (sale.retryCount > _maxRetries || DateTime.now().difference(sale.createdAt).inDays > _maxAgeDays) {
        final conflicted = ConflictedSale(
          id: sale.id,
          saleData: sale.saleData,
          conflictReason: 'Sale expired in offline queue (Max retries or TTL reached)',
          conflictedAt: DateTime.now(),
        );
        await OfflineService.addConflictedSale(conflicted);
        await OfflineService.removeSale(sale.id);
        continue;
      }

      try {
        if (bizId == null) continue;
        sale.saleData['businessId'] = bizId;
        sale.saleData['idempotencyKey'] = sale.id;
        await FunctionsService.call('createSale', sale.saleData);
        await OfflineService.removeSale(sale.id);
      } on FunctionsException catch (e) {
        if (e.message.contains('CONFLICT:')) {
          final rawJson = e.message.split('CONFLICT:').last;
          Map<String, dynamic>? details;
          try {
            details = Map<String, dynamic>.from(jsonDecode(rawJson) as Map);
          } catch (_) {}
          final pName = details?['productName'];
          final avail = details?['availableQty'];
          final req = details?['requestedQty'];
          final conflicted = ConflictedSale(
            id: sale.id,
            saleData: sale.saleData,
            conflictReason: pName != null
                ? 'Insufficient stock for $pName (Available: $avail, Requested: $req)'
                : 'Stock conflict during offline sync',
            conflictDetails: details,
            conflictedAt: DateTime.now(),
          );
          await OfflineService.addConflictedSale(conflicted);
          await OfflineService.removeSale(sale.id);
        } else if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          sale.retryCount++;
          await OfflineService.enqueueSale(sale);
          await OfflineService.removeSale(sale.id);
          rethrow;
        } else {
          await OfflineService.removeSale(sale.id);
        }
      }
    }
  }

  Future<void> _syncPayments(AuthProvider auth) async {
    final payments = OfflineService.getPendingPayments();
    final bizId = auth.businessId;

    for (final payment in payments) {
      if (payment.retryCount > _maxRetries || DateTime.now().difference(payment.createdAt).inDays > _maxAgeDays) {
        await OfflineService.removePayment(payment.id);
        continue;
      }

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
          rethrow;
        }
        await OfflineService.removePayment(payment.id);
      }
    }
  }

  Future<void> _syncInventory(AuthProvider auth) async {
    final updates = OfflineService.getPendingInventoryUpdates();
    final bizId = auth.businessId;

    for (final update in updates) {
      if (update.retryCount > _maxRetries || DateTime.now().difference(update.createdAt).inDays > _maxAgeDays) {
        await OfflineService.removeInventoryUpdate(update.id);
        continue;
      }

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
          rethrow;
        }
        await OfflineService.removeInventoryUpdate(update.id);
      }
    }
  }

  void _scheduleRetry(AuthProvider auth) {
    _retryTimer?.cancel();
    final delays = [10, 30, 60];
    final delay = _retryAttempt < delays.length
        ? delays[_retryAttempt]
        : delays.last;
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: delay), () {
      syncAll(auth);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
