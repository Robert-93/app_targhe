import 'package:flutter/foundation.dart';

// SyncManager scaffold: supporto opzionale per Firebase/Cloud Firestore.
// Questo file fornisce un'interfaccia e un comportamento di base per
// abilitare/disabilitare la sincronizzazione. L'integrazione reale con
// Firestore viene eseguita solo se si aggiungono e configurano i pacchetti
// firebase_core e cloud_firestore e si forniscono le credenziali di progetto.

class SyncManager {
  bool _enabled = false;
  bool get isEnabled => _enabled;

  // Chiamare inizialmente per preparare il manager (es. Firebase.initializeApp())
  Future<void> init() async {
    // Placeholder: non fallire se Firebase non è configurato.
    if (kDebugMode) {
      debugPrint('SyncManager.init() called (no-op scaffold)');
    }
  }

  Future<void> enable() async {
    _enabled = true;
    if (kDebugMode) debugPrint('Sync enabled');
    // TODO: implement real enable logic (start listeners, upload local changes)
  }

  Future<void> disable() async {
    _enabled = false;
    if (kDebugMode) debugPrint('Sync disabled');
    // TODO: stop listeners
  }

  // Placeholder for a method that would push local changes to remote
  Future<void> syncLocalToRemote() async {
    if (!_enabled) return;
    if (kDebugMode) debugPrint('Syncing local data to remote (no-op)');
  }

  // Placeholder for a method that would apply remote changes locally
  void listenRemoteChanges() {
    if (!_enabled) return;
    if (kDebugMode) debugPrint('Listening to remote changes (no-op)');
  }
}
