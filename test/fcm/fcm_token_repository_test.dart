import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/fcm/fcm_token.dart';
import 'package:conecta_creche/fcm/fcm_token_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FcmTokenRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FcmTokenRepository(firestore: firestore);
  });

  test('upsert creates doc with uid/token/platform/timestamps', () async {
    final now = DateTime.utc(2026, 11, 2, 12);

    await repository.upsertToken(
      uid: 'uid-1',
      token: 'fcm-token-a',
      platform: FcmPlatform.android,
      now: now,
    );

    final data = (await firestore
            .collection('fcm_tokens')
            .doc('fcm-token-a')
            .get())
        .data()!;

    expect(data['uid'], 'uid-1');
    expect(data['token'], 'fcm-token-a');
    expect(data['platform'], 'android');
    expect(
      (data['createdAt'] as Timestamp).toDate().isAtSameMomentAs(now),
      isTrue,
    );
    expect(
      (data['updatedAt'] as Timestamp).toDate().isAtSameMomentAs(now),
      isTrue,
    );
  });

  test('upsert updates updatedAt and preserves createdAt', () async {
    final first = DateTime.utc(2026, 11, 2, 10);
    final second = DateTime.utc(2026, 11, 2, 15);

    await repository.upsertToken(
      uid: 'uid-1',
      token: 'fcm-token-a',
      platform: FcmPlatform.android,
      now: first,
    );
    await repository.upsertToken(
      uid: 'uid-1',
      token: 'fcm-token-a',
      platform: FcmPlatform.android,
      now: second,
    );

    final data = (await firestore
            .collection('fcm_tokens')
            .doc('fcm-token-a')
            .get())
        .data()!;

    expect(
      (data['createdAt'] as Timestamp).toDate().isAtSameMomentAs(first),
      isTrue,
    );
    expect(
      (data['updatedAt'] as Timestamp).toDate().isAtSameMomentAs(second),
      isTrue,
    );

    final snapshot = await firestore.collection('fcm_tokens').get();
    expect(snapshot.docs, hasLength(1));
  });

  test('empty token is a no-op', () async {
    await repository.upsertToken(
      uid: 'uid-1',
      token: '',
      platform: FcmPlatform.android,
    );
    final snapshot = await firestore.collection('fcm_tokens').get();
    expect(snapshot.docs, isEmpty);
  });

  test('deleteToken removes doc', () async {
    await repository.upsertToken(
      uid: 'uid-1',
      token: 'fcm-token-a',
      platform: FcmPlatform.android,
    );
    await repository.deleteToken('fcm-token-a');

    final snap =
        await firestore.collection('fcm_tokens').doc('fcm-token-a').get();
    expect(snap.exists, isFalse);
  });

  test('listForUid returns only that user tokens', () async {
    await repository.upsertToken(
      uid: 'uid-1',
      token: 't1',
      platform: FcmPlatform.android,
    );
    await repository.upsertToken(
      uid: 'uid-1',
      token: 't2',
      platform: FcmPlatform.android,
    );
    await repository.upsertToken(
      uid: 'uid-2',
      token: 't3',
      platform: FcmPlatform.ios,
    );

    final forUid1 = await repository.listForUid('uid-1');
    expect(forUid1.map((t) => t.token), unorderedEquals(['t1', 't2']));
    expect(forUid1.every((t) => t.uid == 'uid-1'), isTrue);

    final forUid2 = await repository.listForUid('uid-2');
    expect(forUid2, hasLength(1));
    expect(forUid2.single.platform, FcmPlatform.ios);
  });
}
