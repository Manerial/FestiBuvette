import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/core/services/bluetooth_permissions.dart';
import 'package:festi_buvette_app/features/printer/data/models/printer_device.dart';
import 'package:festi_buvette_app/features/printer/data/services/printer_service.dart';
import 'package:festi_buvette_app/features/printer/providers/printer_provider.dart';

// ─── Mock ─────────────────────────────────────────────────────────────────────

class MockPrinterService implements PrinterService {
  bool btEnabled = true;
  bool connectResult = true;
  bool disconnectResult = true;
  bool writeBytesResult = true;
  bool connectedStatus = false;
  List<PrinterDevice> devices = [];

  @override
  Future<bool> isBluetoothEnabled() async => btEnabled;

  @override
  Future<List<PrinterDevice>> getAvailableDevices() async => devices;

  @override
  Future<bool> connect(String address) async {
    connectedStatus = connectResult;
    return connectResult;
  }

  @override
  Future<bool> get isConnected async => connectedStatus;

  @override
  Future<bool> disconnect() async {
    connectedStatus = false;
    return disconnectResult;
  }

  @override
  Future<bool> writeBytes(List<int> bytes) async => writeBytesResult;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

ProviderContainer makeContainer(
  MockPrinterService mock, {
  BluetoothPermissions? permissions,
}) {
  final container = ProviderContainer(
    overrides: [
      printerProvider.overrideWith(
        () => PrinterNotifier.withService(
          mock,
          // Default to always-granted so existing tests are unaffected.
          permissions: permissions ?? const AlwaysGrantedBluetoothPermissions(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Initial state ──────────────────────────────────────────────────────────

  test('initial state is idle when no saved device', () async {
    final mock = MockPrinterService();
    final container = makeContainer(mock);

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.idle);
    expect(state.connectedDevice, isNull);
  });

  test('auto-reconnects when a device address is saved (E3-5)', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyPrinterAddress: '00:11:22:33:44:55',
      AppConstants.keyPrinterName: 'NETUM',
    });
    final mock = MockPrinterService();
    mock.connectResult = true;
    final container = makeContainer(mock);

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.connected);
    expect(state.connectedDevice?.name, 'NETUM');
  });

  test('stays idle when auto-reconnect fails', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyPrinterAddress: '00:11:22:33:44:55',
      AppConstants.keyPrinterName: 'NETUM',
    });
    final mock = MockPrinterService();
    mock.connectResult = false;
    final container = makeContainer(mock);

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.idle);
    expect(state.connectedDevice?.name, 'NETUM');
  });

  // ── scanDevices ────────────────────────────────────────────────────────────

  test('scanDevices populates availableDevices', () async {
    final mock = MockPrinterService()
      ..devices = [
        const PrinterDevice(name: 'NETUM', address: '00:11:22:33:44:55'),
        const PrinterDevice(name: 'Printer2', address: 'AA:BB:CC:DD:EE:FF'),
      ];
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    await container.read(printerProvider.notifier).scanDevices();

    final state = await container.read(printerProvider.future);
    expect(state.availableDevices.length, 2);
    expect(state.status, PrinterConnectionStatus.idle);
  });

  test('scanDevices sets error when Bluetooth is disabled', () async {
    final mock = MockPrinterService()..btEnabled = false;
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    await container.read(printerProvider.notifier).scanDevices();

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.error);
    expect(state.errorMessage, 'bluetooth_disabled');
  });

  // ── connect ────────────────────────────────────────────────────────────────

  test('connect transitions to connected on success', () async {
    final mock = MockPrinterService()..connectResult = true;
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    const device = PrinterDevice(name: 'NETUM', address: '00:11:22:33:44:55');
    await container.read(printerProvider.notifier).connect(device);

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.connected);
    expect(state.connectedDevice, device);
  });

  test('connect persists address and name in SharedPreferences', () async {
    final mock = MockPrinterService()..connectResult = true;
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    const device = PrinterDevice(name: 'NETUM', address: '00:11:22:33:44:55');
    await container.read(printerProvider.notifier).connect(device);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.keyPrinterAddress), '00:11:22:33:44:55');
    expect(prefs.getString(AppConstants.keyPrinterName), 'NETUM');
  });

  test('connect transitions to error on failure', () async {
    final mock = MockPrinterService()..connectResult = false;
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    const device = PrinterDevice(name: 'NETUM', address: '00:11:22:33:44:55');
    await container.read(printerProvider.notifier).connect(device);

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.error);
  });

  // ── disconnect ─────────────────────────────────────────────────────────────

  test('disconnect clears state and SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyPrinterAddress: '00:11:22:33:44:55',
      AppConstants.keyPrinterName: 'NETUM',
    });
    final mock = MockPrinterService()..connectedStatus = true;
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    await container.read(printerProvider.notifier).disconnect();

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.idle);
    expect(state.connectedDevice, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.keyPrinterAddress), isNull);
    expect(prefs.getString(AppConstants.keyPrinterName), isNull);
  });

  // ── printBytes ─────────────────────────────────────────────────────────────

  test('printBytes returns true on success', () async {
    final mock = MockPrinterService()..writeBytesResult = true;
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    final ok =
        await container.read(printerProvider.notifier).printBytes([0x1B, 0x40]);
    expect(ok, isTrue);
  });

  test('printBytes returns false on failure', () async {
    final mock = MockPrinterService()..writeBytesResult = false;
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    final ok =
        await container.read(printerProvider.notifier).printBytes([0x1B, 0x40]);
    expect(ok, isFalse);
  });

  test('isPrinting is false after printBytes completes', () async {
    final mock = MockPrinterService()..writeBytesResult = true;
    final container = makeContainer(mock);
    await container.read(printerProvider.future);

    await container.read(printerProvider.notifier).printBytes([0x1B, 0x40]);

    final state = await container.read(printerProvider.future);
    expect(state.isPrinting, isFalse);
  });

  // ── Bluetooth permissions ──────────────────────────────────────────────────

  test('build stays idle when permissions are denied (no saved device)', () async {
    final mock = MockPrinterService();
    final container = makeContainer(
      mock,
      permissions: const AlwaysDeniedBluetoothPermissions(),
    );

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.idle);
    expect(state.connectedDevice, isNull);
  });

  test('build stays idle when permissions are denied (saved device present)',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyPrinterAddress: '00:11:22:33:44:55',
      AppConstants.keyPrinterName: 'NETUM',
    });
    final mock = MockPrinterService()..connectResult = true;
    final container = makeContainer(
      mock,
      permissions: const AlwaysDeniedBluetoothPermissions(),
    );

    final state = await container.read(printerProvider.future);
    // Must not auto-reconnect — just restore saved device info.
    expect(state.status, PrinterConnectionStatus.idle);
    expect(state.connectedDevice?.name, 'NETUM');
  });

  test('scanDevices sets error permission_denied when permissions denied',
      () async {
    final mock = MockPrinterService();
    final container = makeContainer(
      mock,
      permissions: const AlwaysDeniedBluetoothPermissions(),
    );
    await container.read(printerProvider.future);

    await container.read(printerProvider.notifier).scanDevices();

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.error);
    expect(state.errorMessage, 'permission_denied');
  });

  test('connect sets error permission_denied when permissions denied', () async {
    final mock = MockPrinterService();
    final container = makeContainer(
      mock,
      permissions: const AlwaysDeniedBluetoothPermissions(),
    );
    await container.read(printerProvider.future);

    const device = PrinterDevice(name: 'NETUM', address: '00:11:22:33:44:55');
    await container.read(printerProvider.notifier).connect(device);

    final state = await container.read(printerProvider.future);
    expect(state.status, PrinterConnectionStatus.error);
    expect(state.errorMessage, 'permission_denied');
  });
}
