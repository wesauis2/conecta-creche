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

  /// Higher number = more privilege. Used for escalation checks.
  int get rank => switch (this) {
        UserRole.admin => 4,
        UserRole.gestao => 3,
        UserRole.cuidador => 2,
        UserRole.responsavel => 1,
        UserRole.convidado => 0,
      };

  bool get canManageUsers => rank >= UserRole.gestao.rank;

  bool canAssign(UserRole target) => target.rank <= rank;

  bool canManage(UserRole other) => other.rank <= rank;

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.gestao => 'Gestão',
        UserRole.cuidador => 'Cuidador',
        UserRole.responsavel => 'Responsável',
        UserRole.convidado => 'Convidado',
      };

  /// Chip / filter label (gestão shown as "Gestor").
  String get filterLabel => switch (this) {
        UserRole.gestao => 'Gestor',
        _ => label,
      };
}
