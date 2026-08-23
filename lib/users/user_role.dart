enum UserRole {
  admin,
  gestao,
  cuidador,
  responsavel,
  convidado;

  static UserRole fromFirestore(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.convidado,
    );
  }
}
