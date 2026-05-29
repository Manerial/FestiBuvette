import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:festi_buvette_app/core/constants/app_constants.dart';
import 'package:festi_buvette_app/features/printer/data/models/printer_device.dart';
import 'package:festi_buvette_app/features/printer/data/services/ticket_service.dart';
import 'package:festi_buvette_app/features/printer/providers/printer_provider.dart';
import 'package:festi_buvette_app/features/products/providers/categories_provider.dart';
import 'package:festi_buvette_app/features/products/providers/products_provider.dart';
import 'package:festi_buvette_app/features/products/services/catalogue_transfer_service.dart';
import 'package:festi_buvette_app/features/report/providers/report_provider.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/core/database/database_helper.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_exception.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_role.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_action_service.dart';
import 'package:festi_buvette_app/features/sync/data/services/sync_server.dart';
import 'package:festi_buvette_app/features/sync/providers/sync_provider.dart';
import 'package:festi_buvette_app/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
      appBar: AppBar(
        title: Text(l10n.settings),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            tooltip: l10n.close,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
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
          const SizedBox(height: 16),
          _AppBarColorPicker(),

          const SizedBox(height: 32),

          // ── Catalogue ─────────────────────────────────────────────────────
          _SectionHeader(label: l10n.catalogueSection),
          const SizedBox(height: 4),
          _CatalogueSection(),

          const SizedBox(height: 32),

          // ── Sync role ─────────────────────────────────────────────────────
          _SyncSection(),

          const SizedBox(height: 32),

          // ── Language ─────────────────────────────────────────────────────
          _SectionHeader(label: l10n.settingsLanguageSection),
          const SizedBox(height: 8),
          _LanguageSelector(),

          const SizedBox(height: 32),

          // ── Bluetooth printer ────────────────────────────────────────────
          _SectionHeader(label: l10n.printerScreenTitle),
          const SizedBox(height: 12),
          _BluetoothSection(),
        ],
      ),
      ),
    );
  }
}

// ─── Local IP provider ────────────────────────────────────────────────────────

/// Lists all non-loopback IPv4 addresses on the device.
/// Used by the control to display its address to the operator.
final _localIpsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );
  return [
    for (final iface in interfaces)
      for (final addr in iface.addresses)
        if (!addr.isLoopback) addr.address,
  ];
});

// ─── Sync section ─────────────────────────────────────────────────────────────

class _SyncSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.syncRole ?? SyncRole.standalone),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: l10n.syncRoleSection),
        const SizedBox(height: 8),
        _RoleSelector(),
        if (role == SyncRole.control) ...[
          const SizedBox(height: 24),
          _SectionHeader(label: l10n.syncSectionTitle),
          const SizedBox(height: 12),
          _ControlSyncSection(),
        ] else if (role == SyncRole.second) ...[
          const SizedBox(height: 24),
          _SectionHeader(label: l10n.syncSectionTitle),
          const SizedBox(height: 12),
          _SecondSyncSection(),
        ],
      ],
    );
  }
}

// ─── Role selector ────────────────────────────────────────────────────────────

class _RoleSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.syncRole ?? SyncRole.standalone),
    );

    return SegmentedButton<SyncRole>(
      segments: [
        ButtonSegment(
          value: SyncRole.standalone,
          label: Text(l10n.syncRoleStandalone),
        ),
        ButtonSegment(
          value: SyncRole.control,
          label: Text(l10n.syncRoleControl),
        ),
        ButtonSegment(
          value: SyncRole.second,
          label: Text(l10n.syncRoleSecond),
        ),
      ],
      selected: {role},
      onSelectionChanged: (selected) =>
          ref.read(settingsProvider.notifier).setSyncRole(selected.first),
    );
  }
}

// ─── Control sync section ─────────────────────────────────────────────────────

class _ControlSyncSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pin = ref.watch(
      settingsProvider.select((s) => s.valueOrNull?.syncPin ?? '------'),
    );
    final connectedSeconds = ref.watch(
      syncProvider.select((s) => s.connectedSeconds),
    );
    final serverError = ref.watch(syncProvider.select((s) => s.serverError));
    final ipsAsync = ref.watch(_localIpsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Server error banner ───────────────────────────────────────────
        if (serverError) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.syncServerStartFailed,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── PIN + Regenerate ──────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.syncPinLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pin,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(l10n.syncPinRegenerate),
              onPressed: () =>
                  ref.read(settingsProvider.notifier).regeneratePin(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Server IP(s) ──────────────────────────────────────────────────
        ...ipsAsync.whenData((ips) => ips).valueOrNull?.map(
              (ip) => _IpRow(
                label: l10n.syncServerAddress,
                address: '$ip:${SyncServer.port}',
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: '$ip:${SyncServer.port}'));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(l10n.syncIpCopied),
                    duration: const Duration(seconds: 2),
                  ));
                },
              ),
            ) ??
            [],

        const SizedBox(height: 8),

        // ── Connected seconds ─────────────────────────────────────────────
        Text(
          l10n.syncConnectedSeconds(connectedSeconds),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _IpRow extends StatelessWidget {
  final String label;
  final String address;
  final VoidCallback onCopy;

  const _IpRow({
    required this.label,
    required this.address,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.wifi, size: 16, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  address,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: onCopy,
            tooltip: label,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─── Second sync section ──────────────────────────────────────────────────────

class _SecondSyncSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SecondSyncSection> createState() => _SecondSyncSectionState();
}

class _SecondSyncSectionState extends ConsumerState<_SecondSyncSection> {
  late final TextEditingController _ipController;
  final TextEditingController _pinController = TextEditingController();

  // Tracks which action button is currently loading (null = idle).
  String? _activeAction;

  @override
  void initState() {
    super.initState();
    final ip =
        ref.read(settingsProvider).valueOrNull?.syncControlIp ?? '192.168.43.1';
    _ipController = TextEditingController(text: ip);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ─── Sync action helpers ──────────────────────────────────────────────────

  Future<void> _runAction(
    String key,
    Future<void> Function(SyncActionService svc, AppLocalizations l10n) fn,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final client = ref.read(syncProvider.notifier).client;
    if (client == null) return;
    setState(() => _activeAction = key);
    try {
      await fn(SyncActionService(DatabaseHelper.instance), l10n);
    } on SyncAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.syncAuthFailed),
          backgroundColor: Colors.red,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.syncConnectionFailed),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _downloadCatalog() => _runAction('catalog', (svc, l10n) async {
        final client = ref.read(syncProvider.notifier).client!;
        await svc.downloadCatalog(client);
        ref.invalidate(productsProvider);
        ref.invalidate(categoriesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.syncCatalogDownloaded),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ));
        }
      });

  Future<void> _sendSales() => _runAction('send', (svc, l10n) async {
        final client = ref.read(syncProvider.notifier).client!;
        final merged = await svc.sendSales(client);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.syncSalesSent(merged)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ));
        }
      });

  Future<void> _downloadSales() => _runAction('download', (svc, l10n) async {
        final client = ref.read(syncProvider.notifier).client!;
        await svc.downloadSales(client);
        ref.invalidate(reportProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.syncSalesDownloaded),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ));
        }
      });

  void _saveIp() =>
      ref.read(settingsProvider.notifier).setSyncControlIp(_ipController.text);

  Future<void> _connect() async {
    _saveIp();
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(syncProvider.notifier)
          .connect(_ipController.text.trim(), _pinController.text.trim());
      if (mounted) {
        _pinController.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.syncConnected),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
      }
    } on SyncAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.syncAuthFailed),
          backgroundColor: Colors.red,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.syncConnectionFailed),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _disconnect() async {
    await ref.read(syncProvider.notifier).disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final syncState = ref.watch(syncProvider);
    final isConnected =
        syncState.connectionStatus == SyncConnectionStatus.connected;
    final isConnecting =
        syncState.connectionStatus == SyncConnectionStatus.connecting;
    final todayDay = ref.watch(
      reportProvider.select((a) => a.valueOrNull?.todayBusinessDay),
    );
    final isDayInProgress = todayDay != null && !todayDay.isClosed;
    final isDayClosed = todayDay != null && todayDay.isClosed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Status ──────────────────────────────────────────────────────
        Row(
          children: [
            Icon(
              isConnected
                  ? Icons.wifi
                  : (isConnecting ? Icons.wifi_find : Icons.wifi_off),
              size: 18,
              color: isConnected
                  ? Colors.green
                  : (isConnecting ? Colors.orange : Colors.grey),
            ),
            const SizedBox(width: 8),
            Text(
              isConnected
                  ? l10n.syncConnectedTo(
                      syncState.connectedToAddress ?? _ipController.text,
                    )
                  : (isConnecting ? l10n.syncConnecting : l10n.syncDisconnected),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isConnected
                        ? Colors.green
                        : (isConnecting ? Colors.orange : Colors.grey),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── IP field ─────────────────────────────────────────────────────
        TextField(
          controller: _ipController,
          decoration: InputDecoration(
            labelText: l10n.syncControlIpLabel,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
          enabled: !isConnected,
          onSubmitted: (_) => _saveIp(),
        ),
        const SizedBox(height: 8),

        // ── PIN input ─────────────────────────────────────────────────────
        TextField(
          controller: _pinController,
          decoration: InputDecoration(
            labelText: l10n.syncPinLabel,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          enabled: !isConnected,
          obscureText: false,
        ),
        const SizedBox(height: 12),

        // ── Connect / Disconnect button ───────────────────────────────────
        if (!isConnected)
          FilledButton(
            onPressed: isConnecting ? null : _connect,
            child: isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.syncConnectButton),
          )
        else
          OutlinedButton(
            onPressed: _disconnect,
            child: Text(l10n.syncDisconnectButton),
          ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        // ── Action buttons ────────────────────────────────────────────────
        _SyncActionButton(
          label: l10n.syncDownloadCatalog,
          icon: Icons.download_outlined,
          enabled: isConnected && !isDayInProgress && _activeAction == null,
          isLoading: _activeAction == 'catalog',
          onPressed: _downloadCatalog,
        ),
        const SizedBox(height: 8),
        _SyncActionButton(
          label: l10n.syncSendSales,
          icon: Icons.upload_outlined,
          enabled: isConnected && isDayClosed && _activeAction == null,
          isLoading: _activeAction == 'send',
          onPressed: _sendSales,
        ),
        const SizedBox(height: 8),
        _SyncActionButton(
          label: l10n.syncDownloadSales,
          icon: Icons.download_outlined,
          enabled: isConnected && isDayClosed && _activeAction == null,
          isLoading: _activeAction == 'download',
          onPressed: _downloadSales,
        ),
      ],
    );
  }
}

// ─── Sync action button ───────────────────────────────────────────────────────

class _SyncActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SyncActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
      onPressed: enabled ? onPressed : null,
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

// ─── AppBar color picker ──────────────────────────────────────────────────────

class _AppBarColorPicker extends ConsumerWidget {
  static const _palette = [
    Color(0xFFFFA946), // Orange (default)
    Color(0xFFE53935), // Red
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF3F51B5), // Indigo
    Color(0xFF1E88E5), // Blue
    Color(0xFF00897B), // Teal
    Color(0xFF43A047), // Green
    Color(0xFFF4511E), // Deep Orange
    Color(0xFF8D6E63), // Brown
    Color(0xFF546E7A), // Blue Grey
    Color(0xFF37474F), // Slate
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(settingsProvider).valueOrNull?.appBarColor ??
        AppConstants.defaultAppBarColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsAppBarColor,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in _palette)
              GestureDetector(
                onTap: () =>
                    ref.read(settingsProvider.notifier).setAppBarColor(color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.toARGB32() == current.toARGB32()
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: color.toARGB32() == current.toARGB32()
                      ? Icon(
                          Icons.check,
                          size: 18,
                          color: color.computeLuminance() > 0.4
                              ? Colors.black87
                              : Colors.white,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ],
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

// ─── Catalogue export / import ───────────────────────────────────────────────

class _CatalogueSection extends ConsumerWidget {
  final _service = CatalogueTransferService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.upload_outlined),
          title: Text(l10n.catalogueExport),
          subtitle: Text(l10n.catalogueExportSubtitle),
          onTap: () => _export(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download_outlined),
          title: Text(l10n.catalogueImport),
          subtitle: Text(l10n.catalogueImportSubtitle),
          onTap: () => _import(context, ref),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      await _service.exportCatalogue();
    } catch (_) {
      // share_plus throws if the user dismisses the sheet on some platforms;
      // treat as a silent cancel.
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final data = await _service.pickAndParseCatalogue();
      if (data == null || !context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.catalogueImportConfirmTitle),
          content: Text(l10n.catalogueImportConfirmMessage(
            data.productsCount,
            data.categoriesCount,
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.catalogueImportAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      await _service.applyCatalogue(data);

      ref.invalidate(productsProvider);
      ref.invalidate(categoriesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.catalogueImported(
              data.productsCount,
              data.categoriesCount,
            )),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.catalogueImportError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.catalogueImportError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
