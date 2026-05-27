import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

// ─── Abstract interface ───────────────────────────────────────────────────────
// Allows mocking in unit tests without a real device.

abstract class BluetoothPermissions {
  const BluetoothPermissions();

  /// Returns true if all required BT permissions are already granted.
  Future<bool> hasPermissions();

  /// Requests any missing permissions.
  /// Returns true only if every required permission ends up granted.
  Future<bool> requestPermissions();

  /// Opens the OS app-settings page so the user can grant denied permissions.
  Future<bool> openSettings() => openAppSettings();
}

// ─── Production implementation ────────────────────────────────────────────────

class DefaultBluetoothPermissions extends BluetoothPermissions {
  const DefaultBluetoothPermissions();

  /// Android 12+ needs BLUETOOTH_SCAN + BLUETOOTH_CONNECT.
  /// iOS needs a single Permission.bluetooth (covers scan & connect).
  /// On Android < 12, permission_handler automatically maps to the legacy
  /// BLUETOOTH / BLUETOOTH_ADMIN permissions declared in AndroidManifest.xml.
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

/// Always grants permissions — use in unit tests.
class AlwaysGrantedBluetoothPermissions extends BluetoothPermissions {
  const AlwaysGrantedBluetoothPermissions();

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;
}

/// Always denies permissions — use to test the denial flow.
class AlwaysDeniedBluetoothPermissions extends BluetoothPermissions {
  const AlwaysDeniedBluetoothPermissions();

  @override
  Future<bool> hasPermissions() async => false;

  @override
  Future<bool> requestPermissions() async => false;
}
