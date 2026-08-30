import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.role,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;

  factory UserProfile.fromFirestore({
    required Map<String, dynamic> userData,
    Map<String, dynamic>? roleData,
  }) {
    final legacyRole = userData['role'] as String?;
    final roleValue = roleData?['role'] as String? ?? legacyRole;

    return UserProfile(
      uid: userData['uid'] as String,
      email: userData['email'] as String?,
      displayName: userData['displayName'] as String?,
      photoUrl: userData['photoUrl'] as String?,
      role: UserRole.fromFirestore(roleValue),
    );
  }

  bool get isPendingApproval => role == UserRole.convidado;

  bool get canManageUsers => role.canManageUsers;
}
