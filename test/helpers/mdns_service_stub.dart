import 'package:festi_buvette_app/features/sync/data/services/mdns_service.dart';

/// No-op MdnsService for unit tests.
/// Returns null immediately from discover() and is a no-op for announce/stop.
class NoOpMdnsService extends MdnsService {
  @override
  Future<void> announce(int port) async {}

  @override
  Future<({String ip, int port})?> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      null;

  @override
  Future<void> stop() async {}
}
