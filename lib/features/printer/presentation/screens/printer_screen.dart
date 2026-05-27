import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_pay_app/core/constants/app_constants.dart';
import 'package:ludo_pay_app/features/settings/providers/settings_provider.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';

class PrinterScreen extends ConsumerStatefulWidget {
  const PrinterScreen({super.key});

  @override
  ConsumerState<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends ConsumerState<PrinterScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the current persisted name if already loaded.
    final currentName =
        ref.read(settingsProvider).valueOrNull?.appName ?? AppConstants.appName;
    _nameController = TextEditingController(text: currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName(BuildContext context) async {
    await ref.read(settingsProvider.notifier).setAppName(_nameController.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.settingsAppNameSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Populate controller once settings finish loading (handles cold start).
    ref.listen<AsyncValue<SettingsState>>(settingsProvider, (prev, next) {
      if (prev?.valueOrNull == null && next.valueOrNull != null) {
        _nameController.text = next.value!.appName;
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.printerScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── App settings ────────────────────────────────────────────────
          _SectionHeader(label: l10n.settingsAppSection),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsAppNameLabel,
                    hintText: l10n.settingsAppNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _saveName(context),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton(
                  onPressed: () => _saveName(context),
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Language ─────────────────────────────────────────────────────
          _SectionHeader(label: l10n.settingsLanguageSection),
          const SizedBox(height: 8),
          _LanguageSelector(),

          const SizedBox(height: 32),

          // ── Bluetooth printer ────────────────────────────────────────────
          _SectionHeader(label: l10n.settingsPrinterSection),
          const SizedBox(height: 16),
          Center(
            child: Text(
              l10n.printerSettingsPlaceholder,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Language selector ────────────────────────────────────────────────────────

class _LanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(settingsProvider).valueOrNull?.locale;

    return SegmentedButton<String?>(
      segments: [
        ButtonSegment(value: null, label: Text(l10n.settingsLanguageSystem)),
        ButtonSegment(value: 'fr', label: Text(l10n.settingsLanguageFr)),
        ButtonSegment(value: 'en', label: Text(l10n.settingsLanguageEn)),
      ],
      selected: {currentLocale},
      onSelectionChanged: (selected) =>
          ref.read(settingsProvider.notifier).setLocale(selected.first),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1,
          ),
    );
  }
}
