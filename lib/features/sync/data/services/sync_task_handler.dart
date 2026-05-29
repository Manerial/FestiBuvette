import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(SyncTaskHandler());
}

/// Minimal foreground task handler.
/// The actual HTTP server runs in the main Flutter isolate; this handler exists
/// solely to keep the Android process alive (WakeLock) when the screen is off.
class SyncTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
