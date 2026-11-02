import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/mural/mural_post.dart';
import 'package:conecta_creche/mural/mural_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MuralRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = MuralRepository(firestore: firestore);
  });

  group('createPost', () {
    test('persists audit fields and defaults effectiveAt to releasedAt',
        () async {
      final released = DateTime.utc(2026, 9, 12, 10);

      final id = await repository.createPost(
        title: 'Confraternização',
        body: 'Saiba mais no mural.',
        kind: MuralPostKind.evento,
        createdBy: 'uid-gestao',
        releasedAt: released,
      );

      final doc = await firestore.collection('mural_posts').doc(id).get();
      final data = doc.data()!;

      expect(data['title'], 'Confraternização');
      expect(data['body'], 'Saiba mais no mural.');
      expect(data['kind'], 'evento');
      expect(data['createdBy'], 'uid-gestao');
      expect(data['updatedBy'], 'uid-gestao');
      expect(data['createdAt'], isNotNull);
      expect(data['updatedAt'], isNotNull);
      expect(
        (data['releasedAt'] as Timestamp).toDate().isAtSameMomentAs(released),
        isTrue,
      );
      expect(
        (data['effectiveAt'] as Timestamp).toDate().isAtSameMomentAs(released),
        isTrue,
      );
    });

    test('keeps distinct effectiveAt when provided', () async {
      final released = DateTime.utc(2026, 9, 12, 10);
      final effective = DateTime.utc(2026, 10, 12, 10);

      final id = await repository.createPost(
        title: 'Dia da criança',
        body: 'Evento em outubro.',
        kind: MuralPostKind.evento,
        createdBy: 'uid-gestao',
        releasedAt: released,
        effectiveAt: effective,
        location: 'Parque',
        scheduleText: '9h às 11h',
      );

      final data =
          (await firestore.collection('mural_posts').doc(id).get()).data()!;
      expect(
        (data['effectiveAt'] as Timestamp).toDate().isAtSameMomentAs(effective),
        isTrue,
      );
      expect(data['location'], 'Parque');
      expect(data['scheduleText'], '9h às 11h');
    });
  });

  group('updatePost', () {
    test('updates fields and stamps updatedBy/updatedAt', () async {
      final id = await repository.createPost(
        title: 'Recado',
        body: 'Texto inicial',
        kind: MuralPostKind.recado,
        createdBy: 'uid-1',
        releasedAt: DateTime.utc(2026, 11, 1),
      );

      await repository.updatePost(
        postId: id,
        updatedBy: 'uid-2',
        title: 'Recado atualizado',
        body: 'Novo texto',
      );

      final data =
          (await firestore.collection('mural_posts').doc(id).get()).data()!;
      expect(data['title'], 'Recado atualizado');
      expect(data['body'], 'Novo texto');
      expect(data['updatedBy'], 'uid-2');
      expect(data['kind'], 'recado');
    });
  });

  group('visibility and ordering', () {
    test('watchVisiblePosts hides items before releasedAt', () async {
      final now = DateTime.utc(2026, 11, 2, 12);

      await repository.createPost(
        title: 'Já liberado',
        body: 'Visível',
        kind: MuralPostKind.comunicado,
        createdBy: 'u1',
        releasedAt: DateTime.utc(2026, 11, 1),
        effectiveAt: DateTime.utc(2026, 11, 1),
      );
      await repository.createPost(
        title: 'Agendado',
        body: 'Ainda não',
        kind: MuralPostKind.comunicado,
        createdBy: 'u1',
        releasedAt: DateTime.utc(2026, 11, 10),
        effectiveAt: DateTime.utc(2026, 11, 10),
      );

      final visible =
          await repository.watchVisiblePosts(asOf: now).first;

      expect(visible.map((p) => p.title), ['Já liberado']);
    });

    test('watchVisiblePosts orders by effectiveAt descending', () async {
      final now = DateTime.utc(2026, 11, 2, 12);

      await repository.createPost(
        title: 'Antigo',
        body: 'a',
        kind: MuralPostKind.comunicado,
        createdBy: 'u1',
        releasedAt: DateTime.utc(2026, 10, 1),
        effectiveAt: DateTime.utc(2026, 10, 1),
      );
      await repository.createPost(
        title: 'Evento futuro liberado',
        body: 'b',
        kind: MuralPostKind.evento,
        createdBy: 'u1',
        releasedAt: DateTime.utc(2026, 9, 12),
        effectiveAt: DateTime.utc(2026, 12, 12),
      );
      await repository.createPost(
        title: 'Recente',
        body: 'c',
        kind: MuralPostKind.recado,
        createdBy: 'u1',
        releasedAt: DateTime.utc(2026, 11, 1),
        effectiveAt: DateTime.utc(2026, 11, 1),
      );

      final visible =
          await repository.watchVisiblePosts(asOf: now).first;

      expect(
        visible.map((p) => p.title),
        ['Evento futuro liberado', 'Recente', 'Antigo'],
      );
    });

    test('watchPosts for gestão includes unreleased, still ordered by effectiveAt',
        () async {
      final now = DateTime.utc(2026, 11, 2, 12);

      await repository.createPost(
        title: 'Liberado',
        body: 'a',
        kind: MuralPostKind.comunicado,
        createdBy: 'u1',
        releasedAt: DateTime.utc(2026, 10, 1),
        effectiveAt: DateTime.utc(2026, 10, 1),
      );
      await repository.createPost(
        title: 'Futuro',
        body: 'b',
        kind: MuralPostKind.evento,
        createdBy: 'u1',
        releasedAt: DateTime.utc(2026, 12, 1),
        effectiveAt: DateTime.utc(2026, 12, 15),
      );

      final all = await repository
          .watchPosts(includeUnreleased: true, asOf: now)
          .first;

      expect(all.map((p) => p.title), ['Futuro', 'Liberado']);
      expect(all.first.isReleased(asOf: now), isFalse);
    });
  });

  group('pagination', () {
    test('listVisiblePosts pageSize limits and continues by effectiveAt',
        () async {
      final now = DateTime.utc(2026, 11, 2, 12);
      for (var i = 0; i < 5; i++) {
        await repository.createPost(
          title: 'Post $i',
          body: 'b',
          kind: MuralPostKind.comunicado,
          createdBy: 'u1',
          releasedAt: DateTime.utc(2026, 10, 1),
          effectiveAt: DateTime.utc(2026, 10, 1 + i),
        );
      }

      final page1 = await repository.listVisiblePosts(
        asOf: now,
        pageSize: 2,
      );
      expect(page1.map((p) => p.title), ['Post 4', 'Post 3']);

      final page2 = await repository.listVisiblePosts(
        asOf: now,
        pageSize: 2,
        startAfterEffectiveAt: page1.last.effectiveAt,
        startAfterId: page1.last.id,
      );
      expect(page2.map((p) => p.title), ['Post 2', 'Post 1']);
    });
  });
}
