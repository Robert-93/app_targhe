import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Firestore emulator sync', () {
    testWidgets('two apps see each others writes via emulator', (tester) async {
      // Initialize two Firebase apps to simulate two devices.
      final app1 = await Firebase.initializeApp(
        name: 'app1',
        options: FirebaseOptions(
          apiKey: 'fake',
          appId: '1:111:android:111',
          messagingSenderId: '111',
          projectId: 'targometro',
        ),
      );
      final app2 = await Firebase.initializeApp(
        name: 'app2',
        options: FirebaseOptions(
          apiKey: 'fake2',
          appId: '1:222:android:222',
          messagingSenderId: '222',
          projectId: 'targometro',
        ),
      );

      final db1 = FirebaseFirestore.instanceFor(app: app1);
      final db2 = FirebaseFirestore.instanceFor(app: app2);

      // Point both instances to the local emulator (default host/port)
      db1.settings = Settings(host: 'localhost:8080', sslEnabled: false, persistenceEnabled: false);
      db2.settings = Settings(host: 'localhost:8080', sslEnabled: false, persistenceEnabled: false);

      final id = 'dip_${DateTime.now().millisecondsSinceEpoch}';
      await db1.collection('dipendenti').doc(id).set({
        'nome': 'Mario',
        'cognome': 'Rossi',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Poll the second client until the document appears (up to ~3s)
      bool found = false;
      for (int i = 0; i < 20; i++) {
        final doc = await db2.collection('dipendenti').doc(id).get();
        if (doc.exists) {
          found = true;
          break;
        }
        await Future.delayed(Duration(milliseconds: 150));
      }

      expect(found, true, reason: 'Document written by app1 should be visible to app2 via emulator');

      final doc2 = await db2.collection('dipendenti').doc(id).get();
      expect(doc2.data()?['nome'], 'Mario');
      expect(doc2.data()?['cognome'], 'Rossi');
    });
  });
}
