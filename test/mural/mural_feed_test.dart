import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/mural/app_notification.dart';
import 'package:conecta_creche/mural/mural_feed.dart';
import 'package:conecta_creche/mural/mural_post.dart';
import 'package:conecta_creche/mural/mural_repository.dart';
import 'package:conecta_creche/mural/notification_repository.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeMuralFeedItems', () {
    test('orders by effectiveAt descending with stable id tie-break', () {
      final posts = [
        MuralPost(
          id: 'p-old',
          title: 'Post antigo',
          body: 'b',
          kind: MuralPostKind.comunicado,
          releasedAt: DateTime.utc(2026, 10, 1),
          effectiveAt: DateTime.utc(2026, 10, 1),
        ),
        MuralPost(
          id: 'p-future',
          title: 'Evento',
          body: 'b',
          kind: MuralPostKind.evento,
          releasedAt: DateTime.utc(2026, 9, 1),
          effectiveAt: DateTime.utc(2026, 12, 1),
        ),
      ];
      final notifications = [
        AppNotification(
          id: 'n1',
          title: 'Notif',
          body: 'n',
          emittedAt: DateTime.utc(2026, 11, 1),
        ),
      ];
      final presenceItems = [
        MuralFeedPresence(
          recordId: 'r1',
          childId: 'c1',
          childName: 'Ana',
          arrivedAt: DateTime.utc(2026, 11, 2, 8),
          departedAt: null,
          isOpen: true,
        ),
      ];
      final incidents = [
        MuralFeedIncident(
          answerId: 'a1',
          recordId: 'r2',
          childId: 'c1',
          childName: 'Ana',
          dayKey: '2026-11-01',
          prompt: 'Temperatura alta?',
          displayValue: 'Sim',
          recordedAt: DateTime.utc(2026, 11, 1, 15),
        ),
      ];

      final merged = mergeMuralFeedItems(
        posts: posts,
        notifications: notifications,
        presenceItems: presenceItems,
        incidents: incidents,
      );

      expect(
        merged.map((i) => i.title).toList(),
        ['Evento', 'Ana — presente', 'Ana — incidente', 'Notif', 'Post antigo'],
      );
      expect(
        merged.map((i) => i.kind).toList(),
        [
          MuralFeedItemKind.post,
          MuralFeedItemKind.presence,
          MuralFeedItemKind.incident,
          MuralFeedItemKind.notification,
          MuralFeedItemKind.post,
        ],
      );
    });
  });

  group('MuralFeedLoader', () {
    late FakeFirebaseFirestore firestore;
    late MuralRepository muralRepository;
    late NotificationRepository notificationRepository;
    late ChildRepository childRepository;
    late PresenceRepository presenceRepository;
    late MuralFeedLoader loader;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      muralRepository = MuralRepository(firestore: firestore);
      notificationRepository = NotificationRepository(firestore: firestore);
      childRepository = ChildRepository(firestore: firestore);
      presenceRepository = PresenceRepository(firestore: firestore);
      loader = MuralFeedLoader(
        muralRepository: muralRepository,
        notificationRepository: notificationRepository,
        childRepository: childRepository,
        presenceRepository: presenceRepository,
      );
    });

    test('equipe sees official posts and notifications, not child presence',
        () async {
      final now = DateTime.utc(2026, 11, 2, 12);

      await muralRepository.createPost(
        title: 'Comunicado',
        body: 'oficial',
        kind: MuralPostKind.comunicado,
        createdBy: 'g1',
        releasedAt: DateTime.utc(2026, 11, 1),
        effectiveAt: DateTime.utc(2026, 11, 1),
      );
      await notificationRepository.createNotification(
        title: 'Push registrado',
        body: 'só registro',
        emittedAt: DateTime.utc(2026, 11, 1, 18),
        userId: 'cuid-1',
      );

      final childId = await childRepository.createChild(
        name: 'Bia',
        createdBy: 'g1',
      );
      await presenceRepository.registerArrival(
        childId: childId,
        dayKey: '2026-11-02',
        arrivedAt: DateTime.utc(2026, 11, 2, 8),
        createdBy: 'cuid-1',
      );

      final feed = await loader.load(
        uid: 'cuid-1',
        role: UserRole.cuidador,
        asOf: now,
      );

      expect(feed.map((i) => i.kind), isNot(contains(MuralFeedItemKind.presence)));
      expect(feed.map((i) => i.kind), isNot(contains(MuralFeedItemKind.incident)));
      expect(feed.map((i) => i.title), ['Push registrado', 'Comunicado']);
    });

    test('responsável merges linked children presence and incidents', () async {
      final now = DateTime.utc(2026, 11, 2, 12);

      await muralRepository.createPost(
        title: 'Recado',
        body: 'para todos',
        kind: MuralPostKind.recado,
        createdBy: 'g1',
        releasedAt: DateTime.utc(2026, 10, 1),
        effectiveAt: DateTime.utc(2026, 10, 1),
      );
      await notificationRepository.createNotification(
        title: 'Notif resp',
        body: 'n',
        emittedAt: DateTime.utc(2026, 11, 1, 9),
        userId: 'resp-1',
      );

      final mine = await childRepository.createChild(
        name: 'Ana',
        createdBy: 'g1',
      );
      final other = await childRepository.createChild(
        name: 'Zoe',
        createdBy: 'g1',
      );
      await childRepository.setChildResponsibles(
        childId: mine,
        responsibleUids: const ['resp-1'],
        updatedBy: 'g1',
      );

      await presenceRepository.registerArrival(
        childId: mine,
        dayKey: '2026-11-02',
        arrivedAt: DateTime.utc(2026, 11, 2, 8),
        createdBy: 'cuid-1',
      );
      await presenceRepository.registerArrival(
        childId: other,
        dayKey: '2026-11-02',
        arrivedAt: DateTime.utc(2026, 11, 2, 9),
        createdBy: 'cuid-1',
      );

      final otherRecords = await presenceRepository.listByChildId(childId: other);
      const question = FormQuestion(
        id: 'q-inc',
        prompt: 'Febre?',
        kind: FormQuestionKind.choice,
        options: [
          FormQuestionOption(id: 'sim', label: 'Sim'),
          FormQuestionOption(id: 'nao', label: 'Não'),
        ],
        flags: FormQuestionFlags(
          duranteDia: true,
          saida: true,
          incident: true,
        ),
        sortIndex: 0,
        active: true,
      );
      // Incident on unlinked child must not appear.
      await presenceRepository.registerAnswer(
        recordId: otherRecords.first.id,
        question: question,
        value: 'sim',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'cuid-1',
        recordedAt: DateTime.utc(2026, 11, 2, 10),
      );

      final mineRecords = await presenceRepository.listByChildId(childId: mine);
      await presenceRepository.registerAnswer(
        recordId: mineRecords.first.id,
        question: question,
        value: 'sim',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'cuid-1',
        recordedAt: DateTime.utc(2026, 11, 2, 10, 30),
      );

      final feed = await loader.load(
        uid: 'resp-1',
        role: UserRole.responsavel,
        asOf: now,
      );

      expect(feed.any((i) => i.title.contains('Zoe')), isFalse);
      expect(
        feed.map((i) => i.title).toList(),
        [
          'Ana — incidente',
          'Ana — presente',
          'Notif resp',
          'Recado',
        ],
      );
    });
  });
}
