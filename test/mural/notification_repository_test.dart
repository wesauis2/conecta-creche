import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/mural/app_notification.dart';
import 'package:conecta_creche/mural/notification_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late NotificationRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = NotificationRepository(firestore: firestore);
  });

  test('create persists title, body and date without FCM fields', () async {
    final emitted = DateTime.utc(2026, 11, 2, 10);

    final id = await repository.createNotification(
      title: 'Aviso',
      body: 'Corpo do aviso',
      emittedAt: emitted,
      userId: 'uid-resp',
      sourceType: NotificationSourceType.muralPost,
      sourceId: 'post-1',
    );

    final data =
        (await firestore.collection('notifications').doc(id).get()).data()!;

    expect(data['title'], 'Aviso');
    expect(data['body'], 'Corpo do aviso');
    expect(data['userId'], 'uid-resp');
    expect(data['sourceType'], 'mural_post');
    expect(data['sourceId'], 'post-1');
    expect(
      (data['emittedAt'] as Timestamp).toDate().isAtSameMomentAs(emitted),
      isTrue,
    );
    expect(data.containsKey('fcm'), isFalse);
    expect(data.containsKey('sent'), isFalse);
  });

  test('broadcast persiste sentinel __broadcast__ para query alinhada às rules',
      () async {
    final id = await repository.createNotification(
      title: 'Broadcast',
      body: 'b',
      emittedAt: DateTime.utc(2026, 11, 1),
    );
    final data =
        (await firestore.collection('notifications').doc(id).get()).data()!;
    expect(data['userId'], NotificationRepository.broadcastUserId);
  });

  test('listForUser returns own + broadcast, ordered by effectiveAt desc',
      () async {
    await repository.createNotification(
      title: 'Antiga',
      body: 'a',
      emittedAt: DateTime.utc(2026, 10, 1),
      userId: 'uid-resp',
    );
    await repository.createNotification(
      title: 'Broadcast',
      body: 'b',
      emittedAt: DateTime.utc(2026, 11, 1),
    );
    await repository.createNotification(
      title: 'Outro user',
      body: 'c',
      emittedAt: DateTime.utc(2026, 11, 2),
      userId: 'uid-outro',
    );
    await repository.createNotification(
      title: 'Recente',
      body: 'd',
      emittedAt: DateTime.utc(2026, 11, 2, 8),
      userId: 'uid-resp',
    );

    final list = await repository.listForUser(
      'uid-resp',
      asOf: DateTime.utc(2026, 11, 2, 12),
    );

    expect(
      list.map((n) => n.title),
      ['Recente', 'Broadcast', 'Antiga'],
    );
  });
}
