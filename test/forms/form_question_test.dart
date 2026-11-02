import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/forms/form_question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormQuestionKind', () {
    test('round-trips firestore values including choice_other', () {
      expect(FormQuestionKind.choice.firestoreValue, 'choice');
      expect(FormQuestionKind.choiceOther.firestoreValue, 'choice_other');
      expect(
        FormQuestionKind.fromFirestore('choice_other'),
        FormQuestionKind.choiceOther,
      );
      expect(FormQuestionKind.fromFirestore('text'), FormQuestionKind.text);
      expect(FormQuestionKind.fromFirestore(null), FormQuestionKind.text);
    });
  });

  group('FormQuestionFlags.shouldPersistAnswer', () {
    test('optional without explicit gesture does not persist', () {
      const flags = FormQuestionFlags(optional: true);
      expect(flags.shouldPersistAnswer(explicitGesture: false), isFalse);
    });

    test('optional with explicit gesture persists', () {
      const flags = FormQuestionFlags(optional: true);
      expect(flags.shouldPersistAnswer(explicitGesture: true), isTrue);
    });

    test('non-optional persists even without gesture', () {
      const flags = FormQuestionFlags(optional: false, saida: true);
      expect(flags.shouldPersistAnswer(explicitGesture: false), isTrue);
    });
  });

  group('FormQuestionFlags.fromMap / toMap', () {
    test('maps snake_case firestore keys', () {
      final flags = FormQuestionFlags.fromMap({
        'durante_dia': true,
        'saida': true,
        'oculta': true,
        'incident': true,
        'optional': true,
      });

      expect(flags.duranteDia, isTrue);
      expect(flags.saida, isTrue);
      expect(flags.oculta, isTrue);
      expect(flags.incident, isTrue);
      expect(flags.optional, isTrue);
      expect(flags.toMap(), {
        'durante_dia': true,
        'saida': true,
        'oculta': true,
        'incident': true,
        'optional': true,
      });
    });

    test('defaults all false when map absent', () {
      expect(FormQuestionFlags.fromMap(null), const FormQuestionFlags());
    });
  });

  group('FormQuestion.matchesCaregiverView', () {
    FormQuestion q({
      bool duranteDia = false,
      bool saida = false,
      bool oculta = false,
      bool incident = false,
      bool optional = false,
    }) {
      return FormQuestion(
        id: 'q1',
        prompt: 'P?',
        kind: FormQuestionKind.choice,
        options: const [],
        flags: FormQuestionFlags(
          duranteDia: duranteDia,
          saida: saida,
          oculta: oculta,
          incident: incident,
          optional: optional,
        ),
        sortIndex: 0,
        active: true,
      );
    }

    test('durante o dia excludes ocultas', () {
      expect(
        q(duranteDia: true).matchesCaregiverView(
          FormCaregiverViewFilter.duranteDia,
        ),
        isTrue,
      );
      expect(
        q(duranteDia: true, oculta: true).matchesCaregiverView(
          FormCaregiverViewFilter.duranteDia,
        ),
        isFalse,
      );
    });

    test('saida / ocultas / incidentes / opcionais filter by flag', () {
      expect(
        q(saida: true).matchesCaregiverView(FormCaregiverViewFilter.saida),
        isTrue,
      );
      expect(
        q(oculta: true).matchesCaregiverView(FormCaregiverViewFilter.ocultas),
        isTrue,
      );
      expect(
        q(incident: true).matchesCaregiverView(
          FormCaregiverViewFilter.incidentes,
        ),
        isTrue,
      );
      expect(
        q(optional: true).matchesCaregiverView(
          FormCaregiverViewFilter.opcionais,
        ),
        isTrue,
      );
      expect(
        q().matchesCaregiverView(FormCaregiverViewFilter.saida),
        isFalse,
      );
    });
  });

  group('FormQuestion.fromFirestore', () {
    test('maps required, options, flags, sortIndex and audit', () {
      final question = FormQuestion.fromFirestore('fq-1', {
        'prompt': 'Comeu bem?',
        'kind': 'choice',
        'options': [
          {'id': 'sim', 'label': 'Sim'},
          {'id': 'nao', 'label': 'Não'},
        ],
        'defaultOptionId': 'sim',
        'flags': {
          'durante_dia': false,
          'saida': true,
          'oculta': false,
          'incident': false,
          'optional': false,
        },
        'sortIndex': 3,
        'active': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
        'createdBy': 'uid-1',
        'updatedBy': 'uid-2',
      });

      expect(question.id, 'fq-1');
      expect(question.prompt, 'Comeu bem?');
      expect(question.kind, FormQuestionKind.choice);
      expect(question.options, [
        const FormQuestionOption(id: 'sim', label: 'Sim'),
        const FormQuestionOption(id: 'nao', label: 'Não'),
      ]);
      expect(question.defaultOptionId, 'sim');
      expect(question.flags.saida, isTrue);
      expect(question.sortIndex, 3);
      expect(question.active, isTrue);
      expect(question.createdBy, 'uid-1');
      expect(question.updatedBy, 'uid-2');
    });

    test('defaults active true, empty options, zero sortIndex', () {
      final question = FormQuestion.fromFirestore('fq-2', {
        'prompt': 'Nota',
        'kind': 'text',
      });

      expect(question.active, isTrue);
      expect(question.options, isEmpty);
      expect(question.sortIndex, 0);
      expect(question.flags, const FormQuestionFlags());
      expect(question.defaultOptionId, isNull);
    });
  });
}
