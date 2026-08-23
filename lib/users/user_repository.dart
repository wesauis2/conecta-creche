import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_profile.dart';
import 'user_role.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> upsertFromFirebaseUser(User user) async {
    final docRef = _users.doc(user.uid);
    final snapshot = await docRef.get();
    final now = FieldValue.serverTimestamp();

    final profileFields = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'updatedAt': now,
    };

    final photoUrl = user.photoURL;
    if (photoUrl != null) {
      profileFields['photoUrl'] = photoUrl;
    }

    if (!snapshot.exists) {
      await docRef.set({
        ...profileFields,
        'role': UserRole.convidado.name,
        'createdAt': now,
      });
      return;
    }

    await docRef.update(profileFields);
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      return UserProfile.fromFirestore(data);
    });
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _users.doc(uid).update({
      'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
