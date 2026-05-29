import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:festi_buvette_app/features/settings/providers/settings_provider.dart';
import 'package:festi_buvette_app/features/sync/data/models/sync_role.dart';
import 'package:festi_buvette_app/features/sync/providers/sync_provider.dart';

/// AppBar icon showing the current sync connection state.
/// Hidden in Standalone mode.
class ConnectionStatusIcon extends ConsumerStatefulWidget {
  const ConnectionStatusIcon({super.key});

  @override
  ConsumerState<ConnectionStatusIcon> createState() =>
      _ConnectionStatusIconState();
}

class _ConnectionStatusIconState extends ConsumerState<ConnectionStatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(settingsProvider
        .select((s) => s.valueOrNull?.syncRole ?? SyncRole.standalone));

    if (role == SyncRole.standalone) return const SizedBox.shrink();

    final status =
        ref.watch(syncProvider.select((s) => s.connectionStatus));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: switch (status) {
        SyncConnectionStatus.connected => const Icon(
            Icons.wifi,
            color: Colors.green,
            size: 22,
          ),
        SyncConnectionStatus.connecting => AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Icon(
              Icons.wifi_find,
              color: Colors.orange.withValues(alpha: 0.3 + 0.7 * _pulse.value),
              size: 22,
            ),
          ),
        SyncConnectionStatus.disconnected => const Icon(
            Icons.wifi_off,
            color: Colors.red,
            size: 22,
          ),
      },
    );
  }
}
