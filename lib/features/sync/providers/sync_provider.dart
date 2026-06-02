import 'dart:ui' show PlatformDispatcher;

import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/printer/data/services/ticket_service.dart';
import 'package:festi_buvette_app/features/printer/providers/printer_provider.dart';
import 'package:festi_buvette_app/features/products/data/repositories/categories_repository.dart';
import 'package:festi_buvette_app/features/products/data/repositories/products_repository.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale.dart';
import 'package:festi_buvette_app/features/sales/data/models/sale_line.dart';
import 'package:festi_buvette_app/features/sales/data/repositories/sales_repository.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_exception.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_role.dart';
import 'package:festi_buvette_app/features/sync/data/services/mdns_service.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_client.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_server.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_task_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Connection status ────────────────────────────────────────────────────────

enum SyncConnectionStatus { disconnected, connecting, connected }

// ─── State ────────────────────────────────────────────────────────────────────

class SyncState {
  final SyncConnectionStatus connectionStatus;
  final int connectedSeconds;
  final String? connectedToAddress;
  final bool serverError;

  const SyncState({
    this.connectionStatus = SyncConnectionStatus.disconnected,
    this.connectedSeconds = 0,
    this.connectedToAddress,
    this.serverError = false,
  });
}

// ─── Injectable factories (overridable in tests) ──────────────────────────────

/// Factory that creates [SyncClient] instances.
/// Override in tests to inject a [MockClient]-backed client.
typedef SyncClientFactory =
    SyncClient Function({required String baseUrl, String? token});

final syncClientFactoryProvider = Provider<SyncClientFactory>((ref) {
  return ({required String baseUrl, String? token}) =>
      SyncClient(baseUrl: baseUrl, token: token);
});

/// Provides the [MdnsService] instance.
/// Override in tests with a no-op implementation to avoid real UDP sockets.
final mdnsServiceProvider = Provider<MdnsService>((ref) => MdnsService());

// ─── Provider ─────────────────────────────────────────────────────────────────

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(
  SyncNotifier.new,
);

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SyncNotifier extends Notifier<SyncState> {
  // Control
  SyncServer? _server;

  // Second
  SyncClient? _client;

  late final MdnsService _mdns;

  @override
  SyncState build() {
    _mdns = ref.read(mdnsServiceProvider);

    ref.listen<AsyncValue<SettingsState>>(
      settingsProvider,
      _onSettingsChanged,
      fireImmediately: true,
    );
    ref.onDispose(() {
      _server?.stop();
      _client?.close();
      _mdns.stop();
      FlutterForegroundTask.stopService();
    });
    return const SyncState();
  }

  // ─── Settings listener ───────────────────────────────────────────────────────

  void _onSettingsChanged(
    AsyncValue<SettingsState>? prev,
    AsyncValue<SettingsState> next,
  ) {
    final prevRole = prev?.valueOrNull?.syncRole;
    final nextRole = next.valueOrNull?.syncRole;
    final nextSettings = next.valueOrNull;
    final nextPin = nextSettings?.syncPin ?? '';

    // Control role transitions
    if (nextRole == SyncRole.control && prevRole != SyncRole.control) {
      _startServer(nextPin);
    } else if (nextRole != SyncRole.control && prevRole == SyncRole.control) {
      _stopServer();
    } else if (nextRole == SyncRole.control &&
        nextPin != (prev?.valueOrNull?.syncPin ?? '')) {
      _server?.updatePin(nextPin);
    }

    // Second role transitions
    if (nextRole == SyncRole.second && prevRole != SyncRole.second) {
      if (nextSettings != null) _tryAutoReconnect(nextSettings);
    } else if (nextRole != SyncRole.second && prevRole == SyncRole.second) {
      _disconnectSecond();
    }
  }

  // ─── Control — server lifecycle ──────────────────────────────────────────────

  Future<void> _startServer(String pin) async {
    await _server?.stop();
    final db = DatabaseHelper.instance;
    _server = SyncServer(
      salesRepo: SalesRepository(db),
      productsRepo: ProductsRepository(db),
      categoriesRepo: CategoriesRepository(db),
      onPrint: _printItems,
      initialPin: pin,
    );
    _server!.onConnectedSecondsChanged = (count) {
      state = SyncState(
        connectionStatus: SyncConnectionStatus.connected,
        connectedSeconds: count,
      );
      _updateNotification(count);
    };
    try {
      await _server!.start();
      await _mdns.announce(SyncServer.port);
      await _startForegroundService(0);
      state = const SyncState(connectionStatus: SyncConnectionStatus.connected);
    } catch (_) {
      await _server?.stop();
      _server = null;
      state = const SyncState(serverError: true);
    }
  }

  Future<void> _stopServer() async {
    await _server?.stop();
    _server = null;
    await _mdns.stop();
    await FlutterForegroundTask.stopService();
    state = const SyncState();
  }

  Future<void> _startForegroundService(int connectedCount) async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'festibuvette_sync',
        channelName: 'FestiBuvette Sync',
        channelDescription: 'Keeps the FestiBuvette HTTP server running.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'FestiBuvette — Service running',
      notificationText: '$connectedCount second(s) connected',
      callback: startForegroundCallback,
    );
  }

  Future<void> _updateNotification(int count) async {
    if (!(await FlutterForegroundTask.isRunningService)) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'FestiBuvette — Service running',
      notificationText: '$count second(s) connected',
    );
  }

  Future<bool> _printItems(List<Map<String, dynamic>> items) async {
    final settings = ref.read(settingsProvider).valueOrNull;
    final businessName = settings?.appName ?? AppConstants.appName;

    final lines = items
        .map(
          (item) => SaleLine(
            saleId: 0,
            productId: item['product_id'] as int?,
            nameSnapshot: item['name'] as String,
            priceSnapshot: (item['price'] as num).toDouble(),
            quantity: item['quantity'] as int,
            subtotal:
                (item['price'] as num).toDouble() * (item['quantity'] as int),
          ),
        )
        .toList();

    final fakeSale = Sale(
      dateTime: DateTime.now().toIso8601String(),
      total: lines.fold(0.0, (sum, l) => sum + l.subtotal),
      businessDayId: 0,
      lines: lines,
    );

    final localeCode =
        settings?.locale ?? PlatformDispatcher.instance.locale.languageCode;
    final thankYouLabel = localeCode == 'fr' ? 'Merci !' : 'Thank you!';
    final totalLabel = localeCode == 'fr' ? 'TOTAL' : 'TOTAL';

    final bytes = await TicketService().buildReceiptFromSale(
      sale: fakeSale,
      businessName: businessName,
      thankYouLabel: thankYouLabel,
      totalLabel: totalLabel,
    );

    return ref.read(printerProvider.notifier).printBytes(bytes);
  }

  // ─── Second — connection lifecycle ───────────────────────────────────────────

  /// Connects to the control at [ip] using [pin].
  /// Attempts mDNS discovery first; falls back to [ip] on failure.
  /// Throws [SyncAuthException] or [SyncNetworkException] on failure.
  Future<void> connect(String ip, String pin) async {
    state = const SyncState(connectionStatus: SyncConnectionStatus.connecting);

    String resolvedIp = ip.trim();
    try {
      final discovered = await _mdns.discover(
        timeout: const Duration(seconds: 3),
      );
      if (discovered != null) resolvedIp = discovered.ip;
    } catch (_) {
      // mDNS failed — use manual IP
    }

    final baseUrl = 'http://$resolvedIp:${SyncServer.port}';
    final factory = ref.read(syncClientFactoryProvider);

    try {
      final token = await factory(baseUrl: baseUrl).authenticate(pin);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keySyncToken, token);
      await prefs.setString(AppConstants.keySyncControlIp, resolvedIp);

      _client?.close();
      _client = factory(baseUrl: baseUrl, token: token);
      state = SyncState(
        connectionStatus: SyncConnectionStatus.connected,
        connectedToAddress: '$resolvedIp:${SyncServer.port}',
      );
    } on SyncAuthException {
      state = const SyncState();
      rethrow;
    } on SyncNetworkException {
      state = const SyncState();
      rethrow;
    } catch (_) {
      state = const SyncState();
      rethrow;
    }
  }

  /// Disconnects the second device and removes the stored token.
  Future<void> disconnect() => _disconnectSecond();

  Future<void> _disconnectSecond() async {
    _client?.close();
    _client = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keySyncToken);
    state = const SyncState();
  }

  /// Tries to reconnect automatically on app launch using the stored token.
  Future<void> _tryAutoReconnect(SettingsState settings) async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(AppConstants.keySyncToken);
    if (storedToken == null) return;

    final ip = settings.syncControlIp;
    final baseUrl = 'http://$ip:${SyncServer.port}';

    state = const SyncState(connectionStatus: SyncConnectionStatus.connecting);

    final factory = ref.read(syncClientFactoryProvider);
    try {
      final client = factory(baseUrl: baseUrl, token: storedToken);
      await client.get('/status');
      _client = client;
      state = SyncState(
        connectionStatus: SyncConnectionStatus.connected,
        connectedToAddress: '$ip:${SyncServer.port}',
      );
    } on SyncAuthException {
      await prefs.remove(AppConstants.keySyncToken);
      state = const SyncState();
    } catch (_) {
      state = const SyncState();
    }
  }

  /// Exposes the active [SyncClient] for P2-4 to P2-7 action buttons.
  SyncClient? get client => _client;
}
