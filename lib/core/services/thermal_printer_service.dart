import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart' as btp;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart' as pbt;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

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
    if (_currentPackage == ThermalPackage.blueThermalPrinter) {
      final blue = btp.BlueThermalPrinter.instance;
      final devices = await blue.getBondedDevices();
      return devices.map((d) => PrinterDevice(name: d.name ?? 'Unknown', address: d.address ?? '')).toList();
    } else {
      final devices = await pbt.PrintBluetoothThermal.pairedBluetooths;
      return devices.map((d) => PrinterDevice(name: d.name, address: d.macAdress)).toList();
    }
  }

  static Future<bool> connect(String macAddress) async {
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
        bool connected = await pbt.PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
        if (connected) {
           _connectedAddress = macAddress;
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString(_prefAddress, macAddress);
           return true;
        }
      }
    } catch (e) {
      print("Printer connection error: $e");
    }
    return false;
  }
  
  static Future<void> disconnect() async {
    try {
      if (_currentPackage == ThermalPackage.blueThermalPrinter) {
         await btp.BlueThermalPrinter.instance.disconnect();
      } else {
         await pbt.PrintBluetoothThermal.disconnect;
      }
    } catch (_) {}
    _connectedAddress = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefAddress);
  }

  static Future<bool> isConnected() async {
    if (_currentPackage == ThermalPackage.blueThermalPrinter) {
      return (await btp.BlueThermalPrinter.instance.isConnected) ?? false;
    } else {
      return await pbt.PrintBluetoothThermal.connectionStatus;
    }
  }

  static Future<void> printReceipt(List<int> bytes) async {
    if (!await isConnected()) {
      if (_connectedAddress != null) {
        bool reconnected = await connect(_connectedAddress!);
        if (!reconnected) return;
      } else {
        return;
      }
    }

    if (_currentPackage == ThermalPackage.blueThermalPrinter) {
      final blue = btp.BlueThermalPrinter.instance;
      await blue.writeBytes(Uint8List.fromList(bytes));
    } else {
      await pbt.PrintBluetoothThermal.writeBytes(bytes);
    }
  }
}
