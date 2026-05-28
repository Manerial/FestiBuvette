import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/features/printer/data/models/printer_device.dart';
import 'package:festi_buvette_app/features/printer/data/services/ticket_service.dart';
import 'package:festi_buvette_app/features/printer/providers/printer_provider.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/l10n/app_localizations.dart';

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

          const SizedBox(height: 16),
          _CartGridViewTile(),
          _HapticFeedbackTile(),

          const SizedBox(height: 32),

          // ── Language ─────────────────────────────────────────────────────
          _SectionHeader(label: l10n.settingsLanguageSection),
          const SizedBox(height: 8),
          _LanguageSelector(),

          const SizedBox(height: 32),

          // ── Bluetooth printer ────────────────────────────────────────────
          _SectionHeader(label: l10n.settings),
          const SizedBox(height: 12),
          _BluetoothSection(),
        ],
      ),
    );
  }
}

// ─── Bluetooth section ────────────────────────────────────────────────────────

class _BluetoothSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final printerAsync = ref.watch(printerProvider);

    return printerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(l10n.errorMessage(e)),
      data: (printer) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Status row ────────────────────────────────────────────────
          _StatusRow(printer: printer),
          const SizedBox(height: 12),

          // ── Action buttons ────────────────────────────────────────────
          _ActionButtons(printer: printer),

          // ── Device list (after scan) ──────────────────────────────────
          if (printer.availableDevices.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...printer.availableDevices.map(
              (d) => _DeviceTile(device: d, currentPrinter: printer),
            ),
          ] else if (printer.isScanning) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ] else if (!printer.isConnected &&
              !printer.isBusy &&
              printer.availableDevices.isEmpty &&
              printer.errorMessage != 'permission_denied') ...[
            const SizedBox(height: 8),
            // Android pairing hint (shown when device list is empty after scan
            // attempt, or before first scan)
            Text(
              l10n.printerAndroidHint,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Status row ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final PrinterState printer;
  const _StatusRow({required this.printer});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final (icon, color, label) = switch (printer.status) {
      PrinterConnectionStatus.connected => (
          Icons.bluetooth_connected,
          colorScheme.primary,
          l10n.printerConnectedTo(printer.connectedDevice?.name ?? ''),
        ),
      PrinterConnectionStatus.scanning => (
          Icons.bluetooth_searching,
          Colors.orange,
          l10n.printerScanning,
        ),
      PrinterConnectionStatus.connecting => (
          Icons.bluetooth_searching,
          Colors.orange,
          l10n.printerConnecting,
        ),
      PrinterConnectionStatus.error => (
          Icons.bluetooth_disabled,
          colorScheme.error,
          _errorLabel(l10n, printer.errorMessage),
        ),
      PrinterConnectionStatus.idle => (
          Icons.bluetooth,
          Colors.grey,
          _idleLabel(l10n, printer),
        ),
    };

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  String _idleLabel(AppLocalizations l10n, PrinterState printer) {
    if (printer.connectedDevice != null) {
      return '${l10n.printerNotConnected} — ${printer.connectedDevice!.name}';
    }
    return l10n.printerNotConnected;
  }

  String _errorLabel(AppLocalizations l10n, String? msg) {
    if (msg == 'bluetooth_disabled') return l10n.printerBluetoothDisabled;
    if (msg == 'permission_denied') return l10n.printerPermissionDenied;
    if (msg == 'connection_failed') return l10n.printerConnectionFailed;
    return l10n.printerConnectionFailed;
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final PrinterState printer;
  const _ActionButtons({required this.printer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(printerProvider.notifier);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!printer.isConnected)
          OutlinedButton.icon(
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(l10n.printerScanDevices),
            onPressed: printer.isBusy ? null : notifier.scanDevices,
          ),
        // Shown when the user permanently denied permissions: deep-link to
        // app settings so they can grant BLUETOOTH_CONNECT / BLUETOOTH_SCAN.
        if (printer.status == PrinterConnectionStatus.error &&
            printer.errorMessage == 'permission_denied')
          OutlinedButton.icon(
            icon: const Icon(Icons.settings_outlined),
            label: Text(l10n.printerOpenSettings),
            onPressed: () => openAppSettings(),
          ),
        if (printer.isConnected) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.bluetooth_disabled),
            label: Text(l10n.printerDisconnect),
            onPressed: printer.isBusy ? null : notifier.disconnect,
          ),
          FilledButton.icon(
            icon: printer.isPrinting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print_outlined),
            label: Text(l10n.printerTestPrint),
            onPressed: printer.isBusy
                ? null
                : () => _testPrint(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _testPrint(BuildContext context, WidgetRef ref) async {
    final businessName = ref.read(settingsProvider).valueOrNull?.appName ??
        AppConstants.appName;
    final bytes = await TicketService().buildTestPage(businessName);
    final ok = await ref.read(printerProvider.notifier).printBytes(bytes);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.printerTestPrint
                : AppLocalizations.of(context)!.printerPrintError,
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ─── Device tile ──────────────────────────────────────────────────────────────

class _DeviceTile extends ConsumerWidget {
  final PrinterDevice device;
  final PrinterState currentPrinter;

  const _DeviceTile({required this.device, required this.currentPrinter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isActive =
        currentPrinter.isConnected &&
        currentPrinter.connectedDevice?.address == device.address;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.print_outlined,
        color: isActive ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        device.name.isEmpty ? device.address : device.name,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        device.address,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.grey.shade500),
      ),
      trailing: isActive
          ? null
          : TextButton(
              onPressed: currentPrinter.isBusy
                  ? null
                  : () => ref
                      .read(printerProvider.notifier)
                      .connect(device),
              child: Text(l10n.printerConnect),
            ),
    );
  }
}

// ─── Cart grid view toggle ────────────────────────────────────────────────────

class _CartGridViewTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final gridView =
        ref.watch(settingsProvider).valueOrNull?.cartGridView ?? true;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.settingsCartGridView),
      subtitle: Text(l10n.settingsCartGridViewSubtitle),
      value: gridView,
      onChanged: (value) =>
          ref.read(settingsProvider.notifier).setCartGridView(value),
    );
  }
}

// ─── Haptic feedback toggle ───────────────────────────────────────────────────

class _HapticFeedbackTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final haptic =
        ref.watch(settingsProvider).valueOrNull?.hapticFeedback ?? true;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.settingsHapticFeedback),
      subtitle: Text(l10n.settingsHapticFeedbackSubtitle),
      value: haptic,
      onChanged: (value) =>
          ref.read(settingsProvider.notifier).setHapticFeedback(value),
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
