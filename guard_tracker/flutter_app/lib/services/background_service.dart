// This is the top-level callback function required by WorkManager.
// It must be a top-level function, not a class method.
@pragma('vm:entry-point')
void callbackDispatcher() {
  // WorkManager triggers this periodically in the background
  // The actual check-in logic is handled via the CheckpointProvider
  // which is initialized from main.dart
}
