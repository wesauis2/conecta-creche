import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/mural/mural_read.dart';
import 'package:conecta_creche/mural/mural_reads_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MuralReadsRepositoryImpl repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = MuralReadsRepositoryImpl(firestore: firestore);
  });

  test('first record persists firstSeenAt/lastSeenAt and channel', () async {
    final seen = DateTime.utc(2026, 11, 2, 10);

    await repository.recordRead(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.mural,
      seenAt: seen,
    );

    final id = MuralRead.docId(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.mural,
    );
    final data =
        (await firestore.collection('mural_reads').doc(id).get()).data()!;

    expect(data['postId'], 'post-1');
    expect(data['uid'], 'uid-resp');
    expect(data['channel'], 'mural');
    expect(
      (data['firstSeenAt'] as Timestamp).toDate().isAtSameMomentAs(seen),
      isTrue,
    );
    expect(
      (data['lastSeenAt'] as Timestamp).toDate().isAtSameMomentAs(seen),
      isTrue,
    );
    expect(data.containsKey('notificationId'), isFalse);
  });

  test('revisit updates lastSeenAt only (idempotent)', () async {
    final first = DateTime.utc(2026, 11, 2, 10);
    final second = DateTime.utc(2026, 11, 2, 15);

    await repository.recordRead(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.mural,
      seenAt: first,
    );
    await repository.recordRead(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.mural,
      seenAt: second,
    );

    final id = MuralRead.docId(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.mural,
    );
    final data =
        (await firestore.collection('mural_reads').doc(id).get()).data()!;

    expect(
      (data['firstSeenAt'] as Timestamp).toDate().isAtSameMomentAs(first),
      isTrue,
    );
    expect(
      (data['lastSeenAt'] as Timestamp).toDate().isAtSameMomentAs(second),
      isTrue,
    );

    final snapshot = await firestore.collection('mural_reads').get();
    expect(snapshot.docs, hasLength(1));
  });

  test('mural and notification channels create separate docs', () async {
    final seen = DateTime.utc(2026, 11, 2, 12);

    await repository.recordRead(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.mural,
      seenAt: seen,
    );
    await repository.recordRead(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.notification,
      notificationId: 'notif-9',
      seenAt: seen,
    );

    final muralId = MuralRead.docId(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.mural,
    );
    final notifId = MuralRead.docId(
      postId: 'post-1',
      uid: 'uid-resp',
      channel: MuralReadChannel.notification,
    );

    final mural =
        (await firestore.collection('mural_reads').doc(muralId).get()).data()!;
    final notif =
        (await firestore.collection('mural_reads').doc(notifId).get()).data()!;

    expect(mural['channel'], 'mural');
    expect(notif['channel'], 'notification');
    expect(notif['notificationId'], 'notif-9');
    expect(await repository.countReaders('post-1'), 1);
  });

  test('countReaders counts distinct uids', () async {
    await repository.recordRead(
      postId: 'post-1',
      uid: 'uid-a',
      channel: MuralReadChannel.mural,
    );
    await repository.recordRead(
      postId: 'post-1',
      uid: 'uid-b',
      channel: MuralReadChannel.mural,
    );
    await repository.recordRead(
      postId: 'post-1',
      uid: 'uid-a',
      channel: MuralReadChannel.notification,
      notificationId: 'n1',
    );
    await repository.recordRead(
      postId: 'post-2',
      uid: 'uid-c',
      channel: MuralReadChannel.mural,
    );

    expect(await repository.countReaders('post-1'), 2);
    expect(await repository.countReaders('post-2'), 1);
    expect(await repository.countReaders('post-x'), 0);
  });
}
