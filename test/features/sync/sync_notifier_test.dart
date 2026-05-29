import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_exception.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_client.dart';
import 'package:festi_buvette_app/features/sync/providers/sync_provider.dart';
import '../../helpers/mdns_service_stub.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Polls the sync state until [target] is reached.
/// Throws if not reached within [maxAttempts] × 10 ms.
Future<void> awaitStatus(
  ProviderContainer container,
  SyncConnectionStatus target, {
  int maxAttempts = 60,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (container.read(syncProvider).connectionStatus == target) return;
    await Future.delayed(const Duration(milliseconds: 10));
  }
  final actual = container.read(syncProvider).connectionStatus;
  throw TestFailure(
      'Expected $target, got $actual after ${maxAttempts * 10} ms');
}

/// Creates a container pre-wired with mock HTTP and a no-op mDNS service.
/// [syncProvider] is eagerly built to avoid a build-before-settings-load
/// race in tests that read [syncProvider] lazily.
ProviderContainer makeContainer({
  required MockClient httpClient,
  Map<String, Object> prefs = const {},
}) {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(overrides: [
    mdnsServiceProvider.overrideWithValue(NoOpMdnsService()),
    syncClientFactoryProvider.overrideWithValue(
      ({required String baseUrl, String? token}) =>
          SyncClient(baseUrl: baseUrl, token: token, client: httpClient),
    ),
  ]);
  // Eagerly build syncProvider so ref.listen(settingsProvider, ...,
  // fireImmediately: true) fires with AsyncLoading — not with AsyncData —
  // giving the listener a clean starting point before settings resolve.
  container.read(syncProvider);
  return container;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── Initial state ─────────────────────────────────────────────────────────

  test('initial state is disconnected', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      mdnsServiceProvider.overrideWithValue(NoOpMdnsService()),
    ]);
    addTearDown(container.dispose);

    expect(
      container.read(syncProvider).connectionStatus,
      SyncConnectionStatus.disconnected,
    );
  });

  // ─── Auto-reconnect ────────────────────────────────────────────────────────

  test('second role with no stored token stays disconnected', () async {
    final container = makeContainer(
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      prefs: {
        AppConstants.keySyncRole: 'second',
        AppConstants.keySyncControlIp: '192.168.43.1',
      },
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(syncProvider).connectionStatus,
      SyncConnectionStatus.disconnected,
    );
  });

  test('second role with valid stored token auto-reconnects', () async {
    final container = makeContainer(
      httpClient: MockClient((req) async {
        if (req.url.path == '/status') {
          return http.Response(
              '{"role":"control","day_started":true}', 200);
        }
        return http.Response('{}', 404);
      }),
      prefs: {
        AppConstants.keySyncRole: 'second',
        AppConstants.keySyncControlIp: '192.168.43.1',
        AppConstants.keySyncToken: 'stored_token',
      },
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future);
    await awaitStatus(container, SyncConnectionStatus.connected);

    final state = container.read(syncProvider);
    expect(state.connectionStatus, SyncConnectionStatus.connected);
    expect(state.connectedToAddress, contains('192.168.43.1'));
  });

  test('second role with expired token removes token and stays disconnected',
      () async {
    final container = makeContainer(
      httpClient: MockClient(
          (_) async => http.Response('{"error":"invalid_token"}', 401)),
      prefs: {
        AppConstants.keySyncRole: 'second',
        AppConstants.keySyncControlIp: '192.168.43.1',
        AppConstants.keySyncToken: 'expired_token',
      },
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future);
    // Wait for connecting → disconnected cycle.
    await awaitStatus(container, SyncConnectionStatus.connecting);
    await awaitStatus(container, SyncConnectionStatus.disconnected);

    expect(
      container.read(syncProvider).connectionStatus,
      SyncConnectionStatus.disconnected,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.keySyncToken), isNull);
  });

  // ─── connect() ────────────────────────────────────────────────────────────

  test('connect() transitions to connected and persists token', () async {
    final container = makeContainer(
      httpClient: MockClient((req) async {
        if (req.url.path == '/auth') {
          return http.Response('{"token":"fresh_token"}', 200);
        }
        return http.Response('{}', 404);
      }),
      prefs: {AppConstants.keySyncRole: 'second'},
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future);

    final connectFuture =
        container.read(syncProvider.notifier).connect('192.168.43.1', '123456');

    // Immediately after calling, should be connecting.
    expect(
      container.read(syncProvider).connectionStatus,
      SyncConnectionStatus.connecting,
    );

    await connectFuture;

    final state = container.read(syncProvider);
    expect(state.connectionStatus, SyncConnectionStatus.connected);
    expect(state.connectedToAddress, contains('192.168.43.1'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.keySyncToken), 'fresh_token');
  });

  test('connect() with wrong PIN throws SyncAuthException and disconnects',
      () async {
    final container = makeContainer(
      httpClient: MockClient(
          (_) async => http.Response('{"error":"invalid_pin"}', 401)),
      prefs: {AppConstants.keySyncRole: 'second'},
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future);

    await expectLater(
      () => container
          .read(syncProvider.notifier)
          .connect('192.168.43.1', 'wrong'),
      throwsA(isA<SyncAuthException>()),
    );

    expect(
      container.read(syncProvider).connectionStatus,
      SyncConnectionStatus.disconnected,
    );
  });

  test('connect() with network error throws SyncNetworkException and disconnects',
      () async {
    final container = makeContainer(
      httpClient: MockClient(
          (_) async => throw http.ClientException('Connection refused')),
      prefs: {AppConstants.keySyncRole: 'second'},
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future);

    await expectLater(
      () => container
          .read(syncProvider.notifier)
          .connect('192.168.43.1', '123456'),
      throwsA(isA<SyncNetworkException>()),
    );

    expect(
      container.read(syncProvider).connectionStatus,
      SyncConnectionStatus.disconnected,
    );
  });

  // ─── disconnect() ─────────────────────────────────────────────────────────

  test('disconnect() clears token and returns to disconnected', () async {
    final container = makeContainer(
      httpClient: MockClient(
          (_) async => http.Response(jsonEncode({'token': 'tok'}), 200)),
      prefs: {AppConstants.keySyncRole: 'second'},
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future);
    await container
        .read(syncProvider.notifier)
        .connect('192.168.43.1', '123456');

    expect(
      container.read(syncProvider).connectionStatus,
      SyncConnectionStatus.connected,
    );

    await container.read(syncProvider.notifier).disconnect();

    expect(
      container.read(syncProvider).connectionStatus,
      SyncConnectionStatus.disconnected,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppConstants.keySyncToken), isNull);
  });
}
