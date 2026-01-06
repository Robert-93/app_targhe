import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'main.dart';


// Full-featured SyncManager: integrates with Cloud Firestore when configured.
// - On enable: initializes Firebase (if needed), uploads local data to Firestore,
//   and starts snapshot listeners to apply remote changes locally.
// - On disable: cancels listeners.
// Conflict resolution: last-write-wins using a `updatedAt` timestamp field.

class SyncManager {
  static final SyncManager instance = SyncManager._internal();
  SyncManager._internal();

  bool _enabled = false;
  bool get isEnabled => _enabled;

  bool _initialized = false;
  bool _applyingRemote = false;

  FirebaseApp? _app;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _dipSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mezziSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _assegnazioniSub;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _app = Firebase.app();
      _initialized = true;
      if (kDebugMode) debugPrint('Firebase already initialized');
    } catch (_) {
      try {
        _app = await Firebase.initializeApp();
        _initialized = true;
        if (kDebugMode) debugPrint('Firebase.initializeApp() done');
      } catch (e) {
        if (kDebugMode) debugPrint('Firebase init failed: $e');
        _initialized = false;
      }
    }
  }

  Future<void> enable() async {
    await init();
    if (!_initialized) {
      if (kDebugMode) debugPrint('SyncManager: Firebase not configured; cannot enable.');
      return;
    }

    if (_enabled) return;
    _enabled = true;

    // Push local data to remote and start listening for remote changes
    await _pushAllLocal();
    _startListeners();

    if (kDebugMode) debugPrint('SyncManager enabled');
  }

  Future<void> disable() async {
    _enabled = false;
    await _cancelListeners();
    if (kDebugMode) debugPrint('SyncManager disabled');
  }

  Future<void> _pushAllLocal() async {
    // Read local storage and write to Firestore
    final localDip = await StorageManager.caricaDipendenti();
    final localMezzi = await StorageManager.caricaMezzi();
    final localAssegn = await StorageManager.caricaAssegnazioni();

    final batch = _db.batch();

    final collDip = _db.collection('dipendenti');
    for (final d in localDip) {
      final ref = collDip.doc(d.id);
      batch.set(ref, {
        ...d.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final collMezzi = _db.collection('mezzi');
    for (final m in localMezzi) {
      final ref = collMezzi.doc(m.id);
      batch.set(ref, {
        ...m.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    final refAssegn = _db.collection('meta').doc('assegnazioni');
    batch.set(refAssegn, {
      'map': localAssegn,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // Public helper to start listening to remote changes (safe to call repeatedly)
  void listenRemoteChanges() {
    if (!_enabled) return;
    _startListeners();
  }

  void _startListeners() {
    _dipSub = _db.collection('dipendenti').snapshots().listen((snap) async {
      if (!_enabled) return;
      final remote = snap.docs.map((d) => Dipendente.fromJson(d.data())).toList();
      _applyingRemote = true;
      await StorageManager.salvaDipendenti(remote);
      _applyingRemote = false;
    });

    _mezziSub = _db.collection('mezzi').snapshots().listen((snap) async {
      if (!_enabled) return;
      final remote = snap.docs.map((d) => Mezzo.fromJson(d.data())).toList();
      _applyingRemote = true;
      await StorageManager.salvaMezzi(remote);
      _applyingRemote = false;
    });

    _assegnazioniSub = _db.collection('meta').doc('assegnazioni').snapshots().listen((doc) async {
      if (!_enabled) return;
      if (!doc.exists) return;
      final data = doc.data()!;
      final map = Map<String, dynamic>.from(data['map'] ?? {});
      final parsed = map.map((k, v) => MapEntry(k, (v as num).toInt()));
      _applyingRemote = true;
      await StorageManager.salvaAssegnazioni(parsed);
      _applyingRemote = false;
    });
  }

  Future<void> _cancelListeners() async {
    await _dipSub?.cancel();
    await _mezziSub?.cancel();
    await _assegnazioniSub?.cancel();
    _dipSub = null;
    _mezziSub = null;
    _assegnazioniSub = null;
  }

  // Called by StorageManager after local save; will push changes to remote unless applying remote
  Future<void> onLocalDipendentiChanged(List<Dipendente> dipendenti) async {
    if (!_enabled || !_initialized || _applyingRemote) return;
    final batch = _db.batch();
    final coll = _db.collection('dipendenti');
    for (final d in dipendenti) {
      final ref = coll.doc(d.id);
      batch.set(ref, {
        ...d.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> onLocalMezziChanged(List<Mezzo> mezzi) async {
    if (!_enabled || !_initialized || _applyingRemote) return;
    final batch = _db.batch();
    final coll = _db.collection('mezzi');
    for (final m in mezzi) {
      final ref = coll.doc(m.id);
      batch.set(ref, {
        ...m.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> onLocalAssegnazioniChanged(Map<String, int> assegn) async {
    if (!_enabled || !_initialized || _applyingRemote) return;
    final ref = _db.collection('meta').doc('assegnazioni');
    await ref.set({'map': assegn, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
