import 'package:conecta_creche/fcm/fcm_sender.dart';
import 'package:conecta_creche/fcm/fcm_token.dart';
import 'package:conecta_creche/fcm/fcm_token_repository.dart';
import 'package:conecta_creche/fcm/notification_dispatch_service.dart';
import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/mural/mural_post.dart';
import 'package:conecta_creche/mural/mural_repository.dart';
import 'package:conecta_creche/mural/notification_repository.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late NotificationRepository notifications;
  late FcmTokenRepository tokens;
  late ChildRepository children;
  late RecordingFcmSender sender;
  late NotificationDispatchService dispatch;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    notifications = NotificationRepository(firestore: firestore);
    tokens = FcmTokenRepository(firestore: firestore);
    children = ChildRepository(firestore: firestore);
    sender = RecordingFcmSender();
    dispatch = NotificationDispatchService(
      notifications: notifications,
      tokens: tokens,
      children: children,
      sender: sender,
    );
  });

  group('dispatchIncident', () {
    test('creates one notification per responsável and attempts FCM', () async {
      final childId = await children.createChild(
        name: 'Ana',
        createdBy: 'gestao',
      );
      await children.setChildResponsibles(
        childId: childId,
        responsibleUids: const ['resp-a', 'resp-b'],
        updatedBy: 'gestao',
      );
      await tokens.upsertToken(
        uid: 'resp-a',
        token: 'token-a',
        platform: FcmPlatform.android,
      );
      await tokens.upsertToken(
        uid: 'resp-b',
        token: 'token-b',
        platform: FcmPlatform.android,
      );

      final result = await dispatch.dispatchIncident(
        childId: childId,
        sourceId: 'answer-1',
        title: 'Incidente · Febre',
        body: '38.5°C',
        emittedAt: DateTime.utc(2026, 11, 2, 14),
      );

      expect(result.notificationIds, hasLength(2));
      expect(result.sendAttempts, 2);
      expect(result.sendSuccesses, 2);
      expect(sender.attempts.map((a) => a.token), ['token-a', 'token-b']);

      final docs = await firestore.collection('notifications').get();
      final userIds = docs.docs.map((d) => d.data()['userId']).toSet();
      expect(userIds, {'resp-a', 'resp-b'});
      expect(
        docs.docs.every((d) => d.data()['sourceType'] == 'incident'),
        isTrue,
      );
      expect(
        docs.docs.every((d) => d.data()['sourceId'] == 'answer-1'),
        isTrue,
      );
    });

    test('skips send when NoOp sender but still persists docs', () async {
      final childId = await children.createChild(
        name: 'Bia',
        createdBy: 'gestao',
      );
      await children.setChildResponsibles(
        childId: childId,
        responsibleUids: const ['resp-x'],
        updatedBy: 'gestao',
      );
      await tokens.upsertToken(
        uid: 'resp-x',
        token: 'tok-x',
        platform: FcmPlatform.android,
      );

      final noOpDispatch = NotificationDispatchService(
        notifications: notifications,
        tokens: tokens,
        children: children,
        sender: const NoOpFcmSender(),
      );

      final result = await noOpDispatch.dispatchIncident(
        childId: childId,
        sourceId: 'a2',
        title: 'Incidente',
        body: 'Queda',
      );

      expect(result.notificationIds, hasLength(1));
      expect(result.sendAttempts, 1);
      expect(result.sendSuccesses, 0);
    });
  });

  group('dispatchMuralPost', () {
    test('broadcast + FCM when requiresNotification and effective now',
        () async {
      await tokens.upsertToken(
        uid: 'u1',
        token: 't1',
        platform: FcmPlatform.android,
      );
      await tokens.upsertToken(
        uid: 'u2',
        token: 't2',
        platform: FcmPlatform.android,
      );

      final effective = DateTime.utc(2026, 11, 1, 9);
      final result = await dispatch.dispatchMuralPost(
        postId: 'post-1',
        title: 'Recado',
        body: 'Leiam o mural',
        effectiveAt: effective,
        requiresNotification: true,
        asOf: DateTime.utc(2026, 11, 2),
      );

      expect(result.notificationIds, hasLength(1));
      expect(result.sendAttempts, 2);
      expect(result.sendSuccesses, 2);

      final data =
          (await firestore.collection('notifications').get()).docs.single.data();
      expect(data.containsKey('userId'), isFalse);
      expect(data['sourceType'], 'mural_post');
      expect(data['sourceId'], 'post-1');
    });

    test('does nothing when effectiveAt is in the future', () async {
      final result = await dispatch.dispatchMuralPost(
        postId: 'post-future',
        title: 'Evento',
        body: 'Outubro',
        effectiveAt: DateTime.utc(2026, 12, 1),
        requiresNotification: true,
        asOf: DateTime.utc(2026, 11, 2),
      );
      expect(result.notificationIds, isEmpty);
      expect(sender.attempts, isEmpty);
    });
  });

  group('wiring', () {
    test('registerAnswer with incident flag creates notifications', () async {
      final childId = await children.createChild(
        name: 'Caio',
        createdBy: 'gestao',
      );
      await children.setChildResponsibles(
        childId: childId,
        responsibleUids: const ['resp-1'],
        updatedBy: 'gestao',
      );
      await tokens.upsertToken(
        uid: 'resp-1',
        token: 'tok-1',
        platform: FcmPlatform.android,
      );

      final presence = PresenceRepository(
        firestore: firestore,
        notificationDispatch: dispatch,
      );
      final recordId = await presence.registerArrival(
        childId: childId,
        dayKey: '2026-11-02',
        arrivedAt: DateTime.utc(2026, 11, 2, 8),
        createdBy: 'cuid',
      );

      const question = FormQuestion(
        id: 'q-inc',
        prompt: 'Febre?',
        kind: FormQuestionKind.choice,
        flags: FormQuestionFlags(incident: true, duranteDia: true),
        sortIndex: 0,
        active: true,
        options: [
          FormQuestionOption(id: 'sim', label: 'Sim'),
          FormQuestionOption(id: 'nao', label: 'Não'),
        ],
      );

      await presence.registerAnswer(
        recordId: recordId,
        question: question,
        value: 'sim',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'cuid',
        recordedAt: DateTime.utc(2026, 11, 2, 10),
      );

      final notifs = await firestore.collection('notifications').get();
      expect(notifs.docs, hasLength(1));
      expect(notifs.docs.single.data()['userId'], 'resp-1');
      expect(notifs.docs.single.data()['sourceType'], 'incident');
      expect(sender.attempts, hasLength(1));
      expect(sender.attempts.single.title, contains('Febre'));
    });

    test('createPost with requiresNotification dispatches when effective now',
        () async {
      await tokens.upsertToken(
        uid: 'u1',
        token: 'tok',
        platform: FcmPlatform.android,
      );
      final mural = MuralRepository(
        firestore: firestore,
        notificationDispatch: dispatch,
      );

      final id = await mural.createPost(
        title: 'Comunicado urgente',
        body: 'Atenção responsáveis',
        kind: MuralPostKind.comunicado,
        createdBy: 'gestao',
        releasedAt: DateTime.utc(2026, 11, 2, 8),
        effectiveAt: DateTime.utc(2026, 11, 2, 8),
        requiresNotification: true,
      );

      final post =
          (await firestore.collection('mural_posts').doc(id).get()).data()!;
      expect(post['requiresNotification'], isTrue);

      final notifs = await firestore.collection('notifications').get();
      expect(notifs.docs, hasLength(1));
      expect(notifs.docs.single.data()['sourceType'], 'mural_post');
      expect(notifs.docs.single.data()['sourceId'], id);
      expect(sender.attempts, hasLength(1));
    });
  });
}
