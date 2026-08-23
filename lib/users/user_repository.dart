import 'dart:async';

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

  CollectionReference<Map<String, dynamic>> get _userRoles =>
      _firestore.collection('user_roles');

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
        'createdAt': now,
      });
    } else {
      await docRef.update(profileFields);
    }

    final roleRef = _userRoles.doc(user.uid);
    final roleSnapshot = await roleRef.get();
    if (!roleSnapshot.exists) {
      await roleRef.set({
        'role': UserRole.convidado.name,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  Stream<UserProfile?> watchProfile(String uid) {
    final controller = StreamController<UserProfile?>();
    DocumentSnapshot<Map<String, dynamic>>? userSnapshot;
    DocumentSnapshot<Map<String, dynamic>>? roleSnapshot;

    void publish() {
      final userData = userSnapshot?.data();
      if (userData == null) {
        controller.add(null);
        return;
      }

      final roleData = roleSnapshot?.data();
      controller.add(
        UserProfile.fromFirestore(
          userData: userData,
          roleData: roleData,
        ),
      );
    }

    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
        userSubscription;
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
        roleSubscription;

    userSubscription = _users.doc(uid).snapshots().listen(
      (snapshot) {
        userSnapshot = snapshot;
        publish();
      },
      onError: controller.addError,
    );

    roleSubscription = _userRoles.doc(uid).snapshots().listen(
      (snapshot) {
        roleSnapshot = snapshot;
        publish();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await userSubscription.cancel();
      await roleSubscription.cancel();
    };

    return controller.stream;
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _users.doc(uid).update({
      'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
