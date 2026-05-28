import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

// ─── Abstract interface ───────────────────────────────────────────────────────
//
// `permission_handler` calls native platform channels (Android / iOS) that are
// unavailable in unit tests.  Injecting this interface into PrinterNotifier
// lets tests substitute a pure-Dart stub without any platform interaction.
//
// The two test stubs below live in lib/ (not test/) because PrinterNotifier
// references them in its withService() constructor, which is also in lib/.

abstract class BluetoothPermissions {
  const BluetoothPermissions();

  /// Returns true if all required Bluetooth permissions are already granted.
  Future<bool> hasPermissions();

  /// Requests any missing permissions.
  /// Returns true only if every required permission ends up granted.
  Future<bool> requestPermissions();

  /// Opens the OS app-settings page so the user can manually grant permissions.
  /// Default implementation delegates to permission_handler's openAppSettings().
  Future<bool> openSettings() => openAppSettings();
}

// ─── Production implementation ────────────────────────────────────────────────

class DefaultBluetoothPermissions extends BluetoothPermissions {
  const DefaultBluetoothPermissions();

  // Android 12+ requires BLUETOOTH_SCAN + BLUETOOTH_CONNECT (split in API 31).
  // On Android < 12, permission_handler automatically remaps these to the legacy
  // BLUETOOTH / BLUETOOTH_ADMIN permissions declared in AndroidManifest.xml —
  // no extra handling needed here.
  // iOS requires a single Permission.bluetooth (covers both scan and connect).
  List<Permission> get _required {
    if (Platform.isAndroid) {
      return [Permission.bluetoothScan, Permission.bluetoothConnect];
    }
    return [Permission.bluetooth];
  }

  @override
  Future<bool> hasPermissions() async {
    for (final p in _required) {
      if (!await p.isGranted) return false;
    }
    return true;
  }

  @override
  Future<bool> requestPermissions() async {
    final statuses = await _required.request();
    return statuses.values.every((s) => s.isGranted);
  }
}

// ─── Test stubs ───────────────────────────────────────────────────────────────
//
// Inject via PrinterNotifier.withService(..., permissions: ...) in tests.
// Use AlwaysGrantedBluetoothPermissions as the default so existing tests are
// unaffected; use AlwaysDeniedBluetoothPermissions to exercise denial flows.

class AlwaysGrantedBluetoothPermissions extends BluetoothPermissions {
  const AlwaysGrantedBluetoothPermissions();

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;
}

class AlwaysDeniedBluetoothPermissions extends BluetoothPermissions {
  const AlwaysDeniedBluetoothPermissions();

  @override
  Future<bool> hasPermissions() async => false;

  @override
  Future<bool> requestPermissions() async => false;
}
