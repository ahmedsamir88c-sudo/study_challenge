import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreHealthCheckService {
  FirestoreHealthCheckService();

  Future<void> verifyReadWrite() async {
    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Firebase must be initialized before testing Firestore.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sign in before testing Firestore read/write access.');
    }

    final checkId = DateTime.now().microsecondsSinceEpoch.toString();
    final document = FirebaseFirestore.instance
        .collection('firestoreHealthChecks')
        .doc(user.uid);

    await document.set({
      'uid': user.uid,
      'checkId': checkId,
      'checkedAt': FieldValue.serverTimestamp(),
    });

    final snapshot = await document.get(
      const GetOptions(source: Source.server),
    );
    if (!snapshot.exists || snapshot.data()?['checkId'] != checkId) {
      throw StateError('Firestore did not return the value that was written.');
    }
  }
}
