import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _wasOffline = false;
  StreamSubscription? _subscription;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get wasOffline => _wasOffline;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    notifyListeners();

    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      final online = !result.contains(ConnectivityResult.none);
      if (online && !_isOnline) {
        _wasOffline = true;
      }
      _isOnline = online;
      notifyListeners();
    });
  }

  void clearWasOffline() {
    _wasOffline = false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
