import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_pay_app/core/constants/app_constants.dart';
import 'package:ludo_pay_app/features/settings/providers/settings_provider.dart';

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

  test('setAppName preserves existing locale', () async {
    SharedPreferences.setMockInitialValues({AppConstants.keyLocale: 'en'});
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setAppName('My Shop');

    final state = await container.read(settingsProvider.future);
    expect(state.locale, 'en');
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

  test('setLocale preserves existing appName', () async {
    SharedPreferences.setMockInitialValues(
        {AppConstants.keyAppName: 'Mon Café'});
    final container = makeContainer();
    await container.read(settingsProvider.future);

    await container.read(settingsProvider.notifier).setLocale('fr');

    final state = await container.read(settingsProvider.future);
    expect(state.appName, 'Mon Café');
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
}
