import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_pay_app/core/constants/app_constants.dart';
import 'package:ludo_pay_app/core/services/bluetooth_permissions.dart';
import 'package:ludo_pay_app/features/printer/data/models/printer_device.dart';
import 'package:ludo_pay_app/features/printer/data/services/printer_service.dart';

// ─── Status enum ──────────────────────────────────────────────────────────────

enum PrinterConnectionStatus { idle, scanning, connecting, connected, error }

// ─── State ────────────────────────────────────────────────────────────────────

class PrinterState {
  final PrinterConnectionStatus status;

  /// Currently connected device, or the last-saved device when idle.
  final PrinterDevice? connectedDevice;

  /// Devices returned by the most recent scan.
  final List<PrinterDevice> availableDevices;

  final String? errorMessage;
  final bool isPrinting;

  const PrinterState({
    this.status = PrinterConnectionStatus.idle,
    this.connectedDevice,
    this.availableDevices = const [],
    this.errorMessage,
    this.isPrinting = false,
  });

  bool get isConnected => status == PrinterConnectionStatus.connected;
  bool get isScanning => status == PrinterConnectionStatus.scanning;
  bool get isConnecting => status == PrinterConnectionStatus.connecting;
  bool get isBusy => isScanning || isConnecting || isPrinting;

  static const _absent = Object();

  PrinterState copyWith({
    PrinterConnectionStatus? status,
    Object? connectedDevice = _absent,
    List<PrinterDevice>? availableDevices,
    Object? errorMessage = _absent,
    bool? isPrinting,
  }) {
    return PrinterState(
      status: status ?? this.status,
      connectedDevice: identical(connectedDevice, _absent)
          ? this.connectedDevice
          : connectedDevice as PrinterDevice?,
      availableDevices: availableDevices ?? this.availableDevices,
      errorMessage: identical(errorMessage, _absent)
          ? this.errorMessage
          : errorMessage as String?,
      isPrinting: isPrinting ?? this.isPrinting,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final printerProvider =
    AsyncNotifierProvider<PrinterNotifier, PrinterState>(PrinterNotifier.new);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class PrinterNotifier extends AsyncNotifier<PrinterState> {
  final PrinterService? _serviceOverride;
  final BluetoothPermissions? _permissionsOverride;

  PrinterNotifier()
      : _serviceOverride = null,
        _permissionsOverride = null;

  /// For unit tests: inject a [PrinterService] mock and optional
  /// [BluetoothPermissions] stub.
  PrinterNotifier.withService(
    PrinterService service, {
    BluetoothPermissions? permissions,
  })  : _serviceOverride = service,
        _permissionsOverride = permissions;

  PrinterService get _service =>
      _serviceOverride ?? const BluetoothPrinterService();

  BluetoothPermissions get _permissions =>
      _permissionsOverride ?? const DefaultBluetoothPermissions();

  // ── Build (auto-reconnect E3-5) ──────────────────────────────────────────

  @override
  Future<PrinterState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString(AppConstants.keyPrinterAddress);
    final savedName =
        prefs.getString(AppConstants.keyPrinterName) ?? '';

    if (savedAddress == null) {
      return const PrinterState(status: PrinterConnectionStatus.idle);
    }

    final savedDevice = PrinterDevice(name: savedName, address: savedAddress);

    // Don't prompt for permissions at startup — check silently and skip
    // the reconnect attempt if they haven't been granted yet.
    final hasPerms = await _permissions.hasPermissions();
    if (!hasPerms) {
      return PrinterState(
        status: PrinterConnectionStatus.idle,
        connectedDevice: savedDevice,
      );
    }

    // Check if already connected (e.g. after hot-reload or screen navigation).
    try {
      final alreadyConnected = await _service.isConnected.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (alreadyConnected) {
        return PrinterState(
          status: PrinterConnectionStatus.connected,
          connectedDevice: savedDevice,
        );
      }

      // Auto-reconnect (E3-5).
      final reconnected = await _service
          .connect(savedAddress)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      return PrinterState(
        status: reconnected
            ? PrinterConnectionStatus.connected
            : PrinterConnectionStatus.idle,
        connectedDevice: savedDevice,
      );
    } catch (_) {
      // Auto-reconnect failed silently — show idle with saved device.
      return PrinterState(
        status: PrinterConnectionStatus.idle,
        connectedDevice: savedDevice,
      );
    }
  }

  // ── Scan ─────────────────────────────────────────────────────────────────

  Future<void> scanDevices() async {
    final current = state.valueOrNull ?? const PrinterState();
    state = AsyncData(current.copyWith(
      status: PrinterConnectionStatus.scanning,
      availableDevices: const [],
      errorMessage: null,
    ));

    // Request permissions before scanning — triggers the OS dialog on first use.
    final granted = await _permissions.requestPermissions();
    if (!granted) {
      state = AsyncData(current.copyWith(
        status: PrinterConnectionStatus.error,
        errorMessage: 'permission_denied',
      ));
      return;
    }

    try {
      final btEnabled = await _service.isBluetoothEnabled();
      if (!btEnabled) {
        state = AsyncData(current.copyWith(
          status: PrinterConnectionStatus.error,
          errorMessage: 'bluetooth_disabled',
        ));
        return;
      }

      final devices = await _service.getAvailableDevices();
      state = AsyncData(current.copyWith(
        status: PrinterConnectionStatus.idle,
        availableDevices: devices,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        status: PrinterConnectionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // ── Connect ──────────────────────────────────────────────────────────────

  Future<void> connect(PrinterDevice device) async {
    final current = state.valueOrNull ?? const PrinterState();

    // Permissions should already be granted after a scan, but re-check to
    // guard against edge cases (e.g. user revoked from Settings mid-session).
    final hasPerms = await _permissions.hasPermissions();
    if (!hasPerms) {
      state = AsyncData(current.copyWith(
        status: PrinterConnectionStatus.error,
        errorMessage: 'permission_denied',
      ));
      return;
    }

    state = AsyncData(current.copyWith(
      status: PrinterConnectionStatus.connecting,
      errorMessage: null,
    ));

    try {
      final success = await _service
          .connect(device.address)
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.keyPrinterAddress, device.address);
        await prefs.setString(AppConstants.keyPrinterName, device.name);

        state = AsyncData(current.copyWith(
          status: PrinterConnectionStatus.connected,
          connectedDevice: device,
        ));
      } else {
        state = AsyncData(current.copyWith(
          status: PrinterConnectionStatus.error,
          errorMessage: 'connection_failed',
        ));
      }
    } catch (e) {
      state = AsyncData(current.copyWith(
        status: PrinterConnectionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // ── Disconnect ───────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    await _service.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyPrinterAddress);
    await prefs.remove(AppConstants.keyPrinterName);

    state = AsyncData(state.valueOrNull?.copyWith(
          status: PrinterConnectionStatus.idle,
          connectedDevice: null,
          availableDevices: const [],
        ) ??
        const PrinterState(status: PrinterConnectionStatus.idle));
  }

  // ── Print bytes ──────────────────────────────────────────────────────────

  Future<bool> printBytes(List<int> bytes) async {
    final current = state.valueOrNull ?? const PrinterState();
    state = AsyncData(current.copyWith(isPrinting: true));
    try {
      final ok = await _service.writeBytes(bytes);
      state = AsyncData(current.copyWith(isPrinting: false));
      return ok;
    } catch (_) {
      state = AsyncData(current.copyWith(isPrinting: false));
      return false;
    }
  }
}
