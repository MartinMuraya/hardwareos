import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/thermal_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<PrinterDevice> _devices = [];
  bool _isLoading = false;
  String? _connectedAddress;
  ThermalPackage _package = ThermalPrinterService.currentPackage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _connectedAddress = ThermalPrinterService.connectedAddress;
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await ThermalPrinterService.getPairedDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      debugPrint('Error loading bluetooth devices: $e');
      if (mounted) setState(() => _devices = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() => _isLoading = true);
    final connected = await ThermalPrinterService.connect(device.address);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (connected) {
          _connectedAddress = device.address;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(connected
                ? 'Connected to ${device.name}'
                : 'Failed to connect')),
      );
    }
  }

  Future<void> _disconnect() async {
    await ThermalPrinterService.disconnect();
    if (mounted) {
      setState(() => _connectedAddress = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected')),
      );
    }
  }

  Future<void> _changePackage(ThermalPackage package) async {
    setState(() {
      _package = package;
      _connectedAddress = null;
    });
    await ThermalPrinterService.setPackage(package);
    _loadDevices();
  }

  Future<void> _testPrint() async {
    // Generate dummy bytes for test print
    // In a real application, we would use esc_pos_utils_plus
    List<int> dummyBytes = [
      0x1B,
      0x40,
      0x0A,
      0x54,
      0x65,
      0x73,
      0x74,
      0x20,
      0x50,
      0x72,
      0x69,
      0x6E,
      0x74,
      0x0A,
      0x0A,
      0x0A,
      0x1D,
      0x56,
      0x41,
      0x00
    ];
    await ThermalPrinterService.printReceipt(dummyBytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go('/dashboard');
            }
          },
        ),
        title: const Text('Thermal Printer Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (kIsWeb ||
                    (defaultTargetPlatform != TargetPlatform.android &&
                        defaultTargetPlatform != TargetPlatform.iOS))
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bluetooth thermal printing is supported on Android & iOS mobile devices. On Web/Desktop browsers, standard browser printing (PDF & Thermal Web Print) is enabled automatically at checkout.',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ListTile(
                  title: const Text('Bluetooth Package'),
                  subtitle: const Text(
                      'Select the underlying library used for printing'),
                  trailing: DropdownButton<ThermalPackage>(
                    value: _package,
                    onChanged: (p) {
                      if (p != null) _changePackage(p);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: ThermalPackage.blueThermalPrinter,
                        child: Text('blue_thermal_printer'),
                      ),
                      DropdownMenuItem(
                        value: ThermalPackage.printBluetoothThermal,
                        child: Text('print_bluetooth_thermal'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paired Devices',
                          style: theme.textTheme.titleMedium),
                      if (_connectedAddress != null)
                        ElevatedButton(
                          onPressed: _testPrint,
                          child: const Text('Test Print'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _devices.isEmpty
                      ? const Center(
                          child: Text(
                              'No paired devices found. Pair a printer in Android Settings first.'))
                      : ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isConnected =
                                device.address == _connectedAddress;
                            return ListTile(
                              leading: const Icon(Icons.print),
                              title: Text(device.name),
                              subtitle: Text(device.address),
                              trailing: isConnected
                                  ? OutlinedButton(
                                      onPressed: _disconnect,
                                      child: const Text('Disconnect',
                                          style: TextStyle(color: Colors.red)),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _connect(device),
                                      child: const Text('Connect'),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
