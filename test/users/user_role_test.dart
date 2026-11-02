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

  group('UserRole.canConfigureForms', () {
    test('is true for gestao and admin', () {
      expect(UserRole.gestao.canConfigureForms, isTrue);
      expect(UserRole.admin.canConfigureForms, isTrue);
    });

    test('is false below gestao', () {
      expect(UserRole.cuidador.canConfigureForms, isFalse);
      expect(UserRole.responsavel.canConfigureForms, isFalse);
      expect(UserRole.convidado.canConfigureForms, isFalse);
    });
  });

  group('UserRole.canPublishMural', () {
    test('is true for gestao and admin', () {
      expect(UserRole.gestao.canPublishMural, isTrue);
      expect(UserRole.admin.canPublishMural, isTrue);
    });

    test('is false below gestao', () {
      expect(UserRole.cuidador.canPublishMural, isFalse);
      expect(UserRole.responsavel.canPublishMural, isFalse);
      expect(UserRole.convidado.canPublishMural, isFalse);
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
