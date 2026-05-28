import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:festi_buvette_app/features/printer/data/models/printer_device.dart';

// ─── Abstract interface ────────────────────────────────────────────────────────
// Allows mocking in unit tests without hardware.

abstract class PrinterService {
  Future<bool> isBluetoothEnabled();

  /// Returns paired devices (Android) or scanned BLE devices (iOS).
  Future<List<PrinterDevice>> getAvailableDevices();

  Future<bool> connect(String address);
  Future<bool> get isConnected;
  Future<bool> disconnect();
  Future<bool> writeBytes(List<int> bytes);
}

// ─── Production implementation ────────────────────────────────────────────────

class BluetoothPrinterService implements PrinterService {
  const BluetoothPrinterService();

  @override
  Future<bool> isBluetoothEnabled() => PrintBluetoothThermal.bluetoothEnabled;

  @override
  Future<List<PrinterDevice>> getAvailableDevices() async {
    final raw = await PrintBluetoothThermal.pairedBluetooths;
    return raw
        .map((d) => PrinterDevice(name: d.name, address: d.macAdress))
        .toList();
  }

  @override
  Future<bool> connect(String address) =>
      PrintBluetoothThermal.connect(macPrinterAddress: address);

  @override
  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  @override
  Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  @override
  Future<bool> writeBytes(List<int> bytes) =>
      PrintBluetoothThermal.writeBytes(bytes);
}
