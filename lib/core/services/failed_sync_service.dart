import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class FailedSyncEntry {
  final String id;
  final String type; // "sale", "payment", "inventory"
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final String reason;

  FailedSyncEntry({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'reason': reason,
  };

  factory FailedSyncEntry.fromJson(Map<String, dynamic> json) => FailedSyncEntry(
    id: json['id'] as String,
    type: json['type'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    reason: json['reason'] as String? ?? "Unknown error",
  );
}

class FailedSyncService extends ChangeNotifier {
  static const _boxName = 'failed_syncs';
  static late Box<String> _box;

  static Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  List<FailedSyncEntry> getEntries() {
    return _box.values.map((raw) =>
      FailedSyncEntry.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map))
    ).toList();
  }

  int get count => _box.length;

  Future<void> addEntry(FailedSyncEntry entry) async {
    await _box.put(entry.id, jsonEncode(entry.toJson()));
    notifyListeners();
  }

  Future<void> removeEntry(String id) async {
    await _box.delete(id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _box.clear();
    notifyListeners();
  }
}
