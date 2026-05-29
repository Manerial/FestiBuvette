import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_role.dart';

void main() {
  // SharedPreferences uses platform channels — requires the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ─── Default values ───────────────────────────────────────────────────────

  test('returns AppConstants.appName when no value is persisted', () async {
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.appName, AppConstants.appName);
  });

  test('locale is null by default', () async {
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.locale, isNull);
  });

  test('returns persisted name on first load', () async {
    SharedPreferences.setMockInitialValues(
        {AppConstants.keyAppName: 'Café du Coin'});
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.appName, 'Café du Coin');
  });

  test('returns persisted locale on first load', () async {
    SharedPreferences.setMockInitialValues(
        {AppConstants.keyLocale: 'fr'});
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.locale, 'fr');
  });

  // ─── setAppName ──────────────────────────────────────────────────────────

  test('setAppName updates state immediately', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setAppName('My Shop');

    final state = await container.read(settingsProvider.future);
    expect(state.appName, 'My Shop');
  });

  test('setAppName trims whitespace', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container
        .read(settingsProvider.notifier)
        .setAppName('  Le Bistrot  ');

    final state = await container.read(settingsProvider.future);
    expect(state.appName, 'Le Bistrot');
  });

  test('setAppName with blank string falls back to default', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setAppName('   ');

    final state = await container.read(settingsProvider.future);
    expect(state.appName, AppConstants.appName);
  });

  test('setAppName persists across provider instances', () async {
    final c1 = makeContainer();
    await c1.read(settingsProvider.future);
    await c1.read(settingsProvider.notifier).setAppName('Chez Marcel');

    final c2 = makeContainer();
    final state = await c2.read(settingsProvider.future);
    expect(state.appName, 'Chez Marcel');
  });

  // ─── setLocale ────────────────────────────────────────────────────────────

  test('setLocale updates state immediately', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setLocale('fr');

    final state = await container.read(settingsProvider.future);
    expect(state.locale, 'fr');
  });

  test('setLocale(null) clears locale', () async {
    SharedPreferences.setMockInitialValues({AppConstants.keyLocale: 'en'});
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setLocale(null);

    final state = await container.read(settingsProvider.future);
    expect(state.locale, isNull);
  });

  test('setLocale persists across provider instances', () async {
    final c1 = makeContainer();
    await c1.read(settingsProvider.future);
    await c1.read(settingsProvider.notifier).setLocale('en');

    final c2 = makeContainer();
    final state = await c2.read(settingsProvider.future);
    expect(state.locale, 'en');
  });

  // ─── setCartGridView ─────────────────────────────────────────────────────

  test('cartGridView defaults to true when not persisted', () async {
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.cartGridView, isTrue);
  });

  test('cartGridView returns persisted value on first load', () async {
    SharedPreferences.setMockInitialValues(
        {AppConstants.keyCartGridView: false});
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.cartGridView, isFalse);
  });

  test('setCartGridView updates state immediately', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setCartGridView(false);

    final state = await container.read(settingsProvider.future);
    expect(state.cartGridView, isFalse);
  });

  test('setCartGridView persists across provider instances', () async {
    final c1 = makeContainer();
    await c1.read(settingsProvider.future);
    await c1.read(settingsProvider.notifier).setCartGridView(false);

    final c2 = makeContainer();
    final state = await c2.read(settingsProvider.future);
    expect(state.cartGridView, isFalse);
  });

  test('setCartGridView preserves existing appName and locale', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyAppName: 'Mon Bar',
      AppConstants.keyLocale: 'fr',
    });
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setCartGridView(false);

    final state = await container.read(settingsProvider.future);
    expect(state.appName, 'Mon Bar');
    expect(state.locale, 'fr');
  });

  // ─── setHapticFeedback ────────────────────────────────────────────────────

  test('hapticFeedback defaults to true when not persisted', () async {
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.hapticFeedback, isTrue);
  });

  test('hapticFeedback returns persisted value on first load', () async {
    SharedPreferences.setMockInitialValues(
        {AppConstants.keyHapticFeedback: false});
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.hapticFeedback, isFalse);
  });

  test('setHapticFeedback updates state immediately', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setHapticFeedback(false);

    final state = await container.read(settingsProvider.future);
    expect(state.hapticFeedback, isFalse);
  });

  test('setHapticFeedback persists across provider instances', () async {
    final c1 = makeContainer();
    await c1.read(settingsProvider.future);
    await c1.read(settingsProvider.notifier).setHapticFeedback(false);

    final c2 = makeContainer();
    final state = await c2.read(settingsProvider.future);
    expect(state.hapticFeedback, isFalse);
  });

  // ─── syncRole ─────────────────────────────────────────────────────────────

  test('syncRole defaults to standalone when not persisted', () async {
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.syncRole, SyncRole.standalone);
  });

  test('syncRole loads persisted value', () async {
    SharedPreferences.setMockInitialValues(
        {AppConstants.keySyncRole: 'control', AppConstants.keySyncPin: '123456'});
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.syncRole, SyncRole.control);
  });

  test('setSyncRole updates state immediately', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setSyncRole(SyncRole.second);

    final state = await container.read(settingsProvider.future);
    expect(state.syncRole, SyncRole.second);
  });

  test('setSyncRole persists across provider instances', () async {
    final c1 = makeContainer();
    await c1.read(settingsProvider.future);
    await c1.read(settingsProvider.notifier).setSyncRole(SyncRole.second);

    final c2 = makeContainer();
    final state = await c2.read(settingsProvider.future);
    expect(state.syncRole, SyncRole.second);
  });

  // ─── syncPin ──────────────────────────────────────────────────────────────

  test('syncPin is null by default in standalone mode', () async {
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.syncPin, isNull);
  });

  test('setSyncRole to control auto-generates a 6-digit PIN', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setSyncRole(SyncRole.control);

    final state = await container.read(settingsProvider.future);
    expect(state.syncPin, isNotNull);
    expect(state.syncPin!.length, 6);
    expect(int.tryParse(state.syncPin!), isNotNull);
  });

  test('setSyncRole to control reuses existing PIN', () async {
    SharedPreferences.setMockInitialValues({AppConstants.keySyncPin: '999888'});
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setSyncRole(SyncRole.control);

    final state = await container.read(settingsProvider.future);
    expect(state.syncPin, '999888');
  });

  test('build in control mode auto-generates PIN when none is stored', () async {
    SharedPreferences.setMockInitialValues({AppConstants.keySyncRole: 'control'});
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.syncPin, isNotNull);
    expect(state.syncPin!.length, 6);
  });

  test('regeneratePin creates a new 6-digit PIN and persists it', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).regeneratePin();

    final state = await container.read(settingsProvider.future);
    expect(state.syncPin, isNotNull);
    expect(state.syncPin!.length, 6);

    final c2 = makeContainer();
    final state2 = await c2.read(settingsProvider.future);
    expect(state2.syncPin, state.syncPin);
  });

  // ─── syncControlIp ────────────────────────────────────────────────────────

  test('syncControlIp defaults to 192.168.43.1', () async {
    final container = makeContainer();
    final state = await container.read(settingsProvider.future);
    expect(state.syncControlIp, '192.168.43.1');
  });

  test('setSyncControlIp updates state immediately', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container
        .read(settingsProvider.notifier)
        .setSyncControlIp('10.0.0.1');

    final state = await container.read(settingsProvider.future);
    expect(state.syncControlIp, '10.0.0.1');
  });

  test('setSyncControlIp persists across provider instances', () async {
    final c1 = makeContainer();
    await c1.read(settingsProvider.future);
    await c1.read(settingsProvider.notifier).setSyncControlIp('10.0.0.5');

    final c2 = makeContainer();
    final state = await c2.read(settingsProvider.future);
    expect(state.syncControlIp, '10.0.0.5');
  });

  test('setSyncControlIp trims whitespace', () async {
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container
        .read(settingsProvider.notifier)
        .setSyncControlIp('  10.0.0.1  ');

    final state = await container.read(settingsProvider.future);
    expect(state.syncControlIp, '10.0.0.1');
  });

  test('setSyncControlIp with empty string is a no-op', () async {
    SharedPreferences.setMockInitialValues(
        {AppConstants.keySyncControlIp: '10.0.0.99'});
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setSyncControlIp('   ');

    final state = await container.read(settingsProvider.future);
    expect(state.syncControlIp, '10.0.0.99');
  });

}
