import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as btp;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart' as pbt;

enum ThermalPackage {
  blueThermalPrinter,
  printBluetoothThermal,
}

class PrinterDevice {
  final String name;
  final String address;

  PrinterDevice({required this.name, required this.address});
}

class ThermalPrinterService {
  static const String _prefPackage = 'thermal_printer_package';
  static const String _prefAddress = 'thermal_printer_address';

  static ThermalPackage _currentPackage = ThermalPackage.blueThermalPrinter;
  static String? _connectedAddress;

  static ThermalPackage get currentPackage => _currentPackage;
  static String? get connectedAddress => _connectedAddress;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final pkg = prefs.getString(_prefPackage);
    if (pkg == ThermalPackage.printBluetoothThermal.name) {
      _currentPackage = ThermalPackage.printBluetoothThermal;
    } else {
      _currentPackage = ThermalPackage.blueThermalPrinter;
    }
    _connectedAddress = prefs.getString(_prefAddress);
  }

  static Future<void> setPackage(ThermalPackage package) async {
    _currentPackage = package;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPackage, package.name);
    // Disconnect if package changes
    await disconnect();
  }

  static Future<List<PrinterDevice>> getPairedDevices() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      debugPrint(
          "Thermal printer Bluetooth plugin is only supported on mobile platforms.");
      return [];
    }
    try {
      if (_currentPackage == ThermalPackage.blueThermalPrinter) {
        final blue = btp.BlueThermalPrinter.instance;
        final devices = await blue.getBondedDevices();
        return devices
            .map((d) => PrinterDevice(
                name: d.name ?? 'Unknown', address: d.address ?? ''))
            .toList();
      } else {
        final devices = await pbt.PrintBluetoothThermal.pairedBluetooths;
        return devices
            .map((d) => PrinterDevice(name: d.name, address: d.macAdress))
            .toList();
      }
    } catch (e) {
      debugPrint("Error fetching paired Bluetooth devices: $e");
      return [];
    }
  }

  static Future<bool> connect(String macAddress) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    try {
      if (_currentPackage == ThermalPackage.blueThermalPrinter) {
        final blue = btp.BlueThermalPrinter.instance;
        final devices = await blue.getBondedDevices();
        final device = devices.firstWhere((d) => d.address == macAddress);
        bool? connected = await blue.connect(device);
        if (connected == true) {
          _connectedAddress = macAddress;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefAddress, macAddress);
          return true;
        }
      } else {
        bool connected = await pbt.PrintBluetoothThermal.connect(
            macPrinterAddress: macAddress);
        if (connected) {
          _connectedAddress = macAddress;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefAddress, macAddress);
          return true;
        }
      }
    } catch (e) {
      // Use debugPrint instead of print to respect production logging guidance
      debugPrint("Printer connection error: $e");
    }
    return false;
  }

  static Future<void> disconnect() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      if (_currentPackage == ThermalPackage.blueThermalPrinter) {
        await btp.BlueThermalPrinter.instance.disconnect();
      } else {
        await pbt.PrintBluetoothThermal.disconnect;
      }
    } catch (e) {
      debugPrint("Printer disconnect error: $e");
    }
    _connectedAddress = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefAddress);
  }

  static Future<bool> isConnected() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    try {
      if (_currentPackage == ThermalPackage.blueThermalPrinter) {
        return (await btp.BlueThermalPrinter.instance.isConnected) ?? false;
      } else {
        return await pbt.PrintBluetoothThermal.connectionStatus;
      }
    } catch (e) {
      debugPrint("Printer isConnected check error: $e");
      return false;
    }
  }

  static Future<bool> printReceipt(List<int> bytes) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      debugPrint(
          "Bluetooth thermal printing unavailable on non-mobile platform.");
      return false;
    }
    try {
      if (_currentPackage == ThermalPackage.blueThermalPrinter) {
        final blue = btp.BlueThermalPrinter.instance;
        if ((await blue.isConnected) == true) {
          await blue.writeBytes(Uint8List.fromList(bytes));
          return true;
        }
      } else {
        final connected = await pbt.PrintBluetoothThermal.connectionStatus;
        if (connected) {
          await pbt.PrintBluetoothThermal.writeBytes(bytes);
          return true;
        }
      }
    } catch (e) {
      debugPrint("Print receipt error: $e");
    }
    return false;
  }
}
