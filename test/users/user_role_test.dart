import 'package:conecta_creche/users/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole.canOperatePresence', () {
    test('is true for cuidador and above', () {
      expect(UserRole.cuidador.canOperatePresence, isTrue);
      expect(UserRole.gestao.canOperatePresence, isTrue);
      expect(UserRole.admin.canOperatePresence, isTrue);
    });

    test('is false below cuidador', () {
      expect(UserRole.responsavel.canOperatePresence, isFalse);
      expect(UserRole.convidado.canOperatePresence, isFalse);
    });
  });

  group('UserRole.canInactivateChild', () {
    test('is true for gestao and admin', () {
      expect(UserRole.gestao.canInactivateChild, isTrue);
      expect(UserRole.admin.canInactivateChild, isTrue);
    });

    test('is false below gestao', () {
      expect(UserRole.cuidador.canInactivateChild, isFalse);
      expect(UserRole.responsavel.canInactivateChild, isFalse);
      expect(UserRole.convidado.canInactivateChild, isFalse);
    });
  });

  group('UserRole.canAdminPresence', () {
    test('is true only for admin', () {
      expect(UserRole.admin.canAdminPresence, isTrue);
    });

    test('is false for every other role', () {
      expect(UserRole.gestao.canAdminPresence, isFalse);
      expect(UserRole.cuidador.canAdminPresence, isFalse);
      expect(UserRole.responsavel.canAdminPresence, isFalse);
      expect(UserRole.convidado.canAdminPresence, isFalse);
    });
  });
}
