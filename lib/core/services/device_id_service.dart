import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';

/// Provides a stable UUID v4 that uniquely identifies this app installation.
///
/// Generated once on first call and persisted in SharedPreferences so the
/// identity survives app restarts. Used as [source_device_token] in the
/// [sales] table so every sale can be traced to its originating device and
/// deduplicated across the fleet via the composite key
/// (source_device_token, source_local_id).
class DeviceIdService {
  DeviceIdService._();

  static String? _cached;

  /// Returns this device's UUID, generating and persisting it on first call.
  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(AppConstants.keyDeviceId);
    if (_cached == null) {
      _cached = _generate();
      await prefs.setString(AppConstants.keyDeviceId, _cached!);
    }
    return _cached!;
  }

  /// Resets the in-memory cache. Call in tests between runs.
  static void resetCache() => _cached = null;

  static String _generate() {
    final rng = Random.secure();
    final bytes = List.generate(16, (_) => rng.nextInt(256));
    // UUID v4 variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20)}';
  }
}
