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

  /// Merges `users` + `user_roles` for gestão/admin user management.
  Stream<List<UserProfile>> watchManagedUsers() {
    final controller = StreamController<List<UserProfile>>();
    QuerySnapshot<Map<String, dynamic>>? usersSnapshot;
    QuerySnapshot<Map<String, dynamic>>? rolesSnapshot;

    void publish() {
      if (usersSnapshot == null || rolesSnapshot == null) {
        return;
      }

      final rolesByUid = <String, Map<String, dynamic>>{
        for (final doc in rolesSnapshot!.docs) doc.id: doc.data(),
      };

      final profiles = <UserProfile>[];
      for (final doc in usersSnapshot!.docs) {
        final userData = doc.data();
        final uid = userData['uid'] as String? ?? doc.id;
        profiles.add(
          UserProfile.fromFirestore(
            userData: {...userData, 'uid': uid},
            roleData: rolesByUid[doc.id] ?? rolesByUid[uid],
          ),
        );
      }

      profiles.sort((a, b) {
        final nameA = (a.displayName ?? a.email ?? a.uid).toLowerCase();
        final nameB = (b.displayName ?? b.email ?? b.uid).toLowerCase();
        return nameA.compareTo(nameB);
      });

      controller.add(profiles);
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        usersSubscription;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        rolesSubscription;

    usersSubscription = _users.snapshots().listen(
      (snapshot) {
        usersSnapshot = snapshot;
        publish();
      },
      onError: controller.addError,
    );

    rolesSubscription = _userRoles.snapshots().listen(
      (snapshot) {
        rolesSnapshot = snapshot;
        publish();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await usersSubscription.cancel();
      await rolesSubscription.cancel();
    };

    return controller.stream;
  }

  Future<void> updateUserRole({
    required String targetUid,
    required UserRole newRole,
    required UserRole callerRole,
    required UserRole targetCurrentRole,
  }) async {
    if (!callerRole.canManageUsers) {
      throw StateError('Sem permissão para alterar papéis.');
    }
    if (!callerRole.canManage(targetCurrentRole)) {
      throw StateError('Não é possível gerenciar um papel acima do seu.');
    }
    if (!callerRole.canAssign(newRole)) {
      throw StateError('Não é possível atribuir um papel acima do seu.');
    }

    await _userRoles.doc(targetUid).update({
      'role': newRole.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDisplayName(String uid, String displayName) async {
    await _users.doc(uid).update({
      'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
