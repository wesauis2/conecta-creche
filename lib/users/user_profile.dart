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

  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    return UserProfile(
      uid: data['uid'] as String,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      role: UserRole.fromFirestore(data['role'] as String?),
    );
  }

  bool get isPendingApproval => role == UserRole.convidado;
}
