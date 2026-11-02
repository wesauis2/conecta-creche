import 'default_form_questions.dart';
import 'form_question.dart';
import 'form_question_repository.dart';

/// Resultado de uma execução de seed/replace.
class FormQuestionSeedResult {
  const FormQuestionSeedResult({
    required this.replace,
    required this.created,
    required this.updated,
    required this.deactivated,
    required this.skipped,
  });

  final bool replace;
  final int created;
  final int updated;
  final int deactivated;
  final int skipped;

  int get touched => created + updated + deactivated;
}

/// Seed idempotente / replace do pacote default em `form_questions`.
///
/// - **Seguro (default):** cria só entradas cujo [DefaultFormQuestion.seedKey]
///   ainda não existe (coleção vazia ou parcial).
/// - **`--replace`:** desativa perguntas ativas e regrava o pacote default
///   (reativa/atualiza por `seedKey` quando já houver doc inativo).
class FormQuestionSeeder {
  FormQuestionSeeder({
    required FormQuestionRepository repository,
    List<DefaultFormQuestion>? package,
    this.actorUid = 'seed-script',
  })  : _repository = repository,
        _package = package ?? defaultFormQuestionsPackage();

  final FormQuestionRepository _repository;
  final List<DefaultFormQuestion> _package;
  final String actorUid;

  Future<FormQuestionSeedResult> seed({bool replace = false}) {
    return replace ? _replace() : _safeSeed();
  }

  Future<FormQuestionSeedResult> _safeSeed() async {
    final existing = await _repository.listQuestions();
    final bySeedKey = <String, FormQuestion>{};
    for (final q in existing) {
      final key = q.seedKey;
      if (key != null && key.isNotEmpty) {
        bySeedKey.putIfAbsent(key, () => q);
      }
    }

    var created = 0;
    var skipped = 0;
    for (final def in _package) {
      if (bySeedKey.containsKey(def.seedKey)) {
        skipped++;
        continue;
      }
      await _create(def);
      created++;
    }

    return FormQuestionSeedResult(
      replace: false,
      created: created,
      updated: 0,
      deactivated: 0,
      skipped: skipped,
    );
  }

  Future<FormQuestionSeedResult> _replace() async {
    final existing = await _repository.listQuestions();
    final bySeedKey = <String, FormQuestion>{};
    for (final q in existing) {
      final key = q.seedKey;
      if (key != null && key.isNotEmpty) {
        bySeedKey.putIfAbsent(key, () => q);
      }
    }

    var deactivated = 0;
    for (final q in existing) {
      if (!q.active) continue;
      await _repository.updateQuestion(
        questionId: q.id,
        updatedBy: actorUid,
        active: false,
      );
      deactivated++;
    }

    var created = 0;
    var updated = 0;
    for (final def in _package) {
      final prior = bySeedKey[def.seedKey];
      if (prior != null) {
        await _repository.updateQuestion(
          questionId: prior.id,
          updatedBy: actorUid,
          prompt: def.prompt,
          kind: def.kind,
          options: def.options,
          defaultOptionId: def.defaultOptionId,
          clearDefaultOptionId: def.defaultOptionId == null,
          flags: def.flags,
          sortIndex: def.sortIndex,
          active: true,
          seedKey: def.seedKey,
        );
        updated++;
      } else {
        await _create(def);
        created++;
      }
    }

    return FormQuestionSeedResult(
      replace: true,
      created: created,
      updated: updated,
      deactivated: deactivated,
      skipped: 0,
    );
  }

  Future<void> _create(DefaultFormQuestion def) {
    return _repository.createQuestion(
      prompt: def.prompt,
      kind: def.kind,
      options: def.options,
      defaultOptionId: def.defaultOptionId,
      flags: def.flags,
      sortIndex: def.sortIndex,
      active: true,
      seedKey: def.seedKey,
      createdBy: actorUid,
    );
  }
}
