import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';

/// Discovers _festibuvette._tcp services over mDNS.
///
/// The control side relies on the manual IP fallback (192.168.43.1) if mDNS
/// discovery is unavailable. Full mDNS advertisement (server side) requires
/// platform-level socket binding that may be restricted on Android — the manual
/// IP is always the reliable fallback.
class MdnsService {
  static const String _serviceType = '_festibuvette._tcp';

  MDnsClient? _announceClient;

  /// Starts the mDNS announce client so the device responds to service queries.
  /// Silently succeeds if the network stack does not support multicast.
  Future<void> announce(int port) async {
    final client = MDnsClient();
    try {
      await client.start(
        listenAddress: InternetAddress.anyIPv4,
      );
      _announceClient = client;
    } catch (_) {
      client.stop();
    }
  }

  /// Discovers the first _festibuvette._tcp service on the local network.
  /// Returns the IP address and port, or null if nothing is found within [timeout].
  Future<({String ip, int port})?> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final client = MDnsClient();
    try {
      await client.start(
        listenAddress: InternetAddress.anyIPv4,
      );
      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(_serviceType))
          .timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final SrvResourceRecord srv in client
            .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName))
            .timeout(
                const Duration(seconds: 2),
                onTimeout: (sink) => sink.close())) {
          await for (final IPAddressResourceRecord addr in client
              .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target))
              .timeout(
                  const Duration(seconds: 2),
                  onTimeout: (sink) => sink.close())) {
            client.stop();
            return (ip: addr.address.address, port: srv.port);
          }
        }
      }
    } catch (_) {
      // Discovery failed; caller falls back to manual IP.
    } finally {
      client.stop();
    }
    return null;
  }

  Future<void> stop() async {
    _announceClient?.stop();
    _announceClient = null;
  }
}
