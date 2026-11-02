import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/fcm/fcm_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromFirestore maps fields and platform', () {
    final token = FcmToken.fromFirestore('tok-1', {
      'uid': 'u1',
      'token': 'tok-1',
      'platform': 'android',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 2)),
    });

    expect(token.id, 'tok-1');
    expect(token.uid, 'u1');
    expect(token.token, 'tok-1');
    expect(token.platform, FcmPlatform.android);
    expect(
      token.createdAt!.isAtSameMomentAs(DateTime.utc(2026, 11, 1)),
      isTrue,
    );
    expect(
      token.updatedAt!.isAtSameMomentAs(DateTime.utc(2026, 11, 2)),
      isTrue,
    );
  });

  test('docIdForToken is the token value', () {
    expect(FcmToken.docIdForToken('abc'), 'abc');
  });

  test('unknown platform falls back to other', () {
    expect(FcmPlatform.fromFirestore('web'), FcmPlatform.other);
    expect(FcmPlatform.fromFirestore(null), FcmPlatform.other);
  });
}
