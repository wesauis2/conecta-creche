import 'dart:convert';
import 'dart:typed_data';

import 'package:conecta_creche/forms/form_media_answer.dart';
import 'package:conecta_creche/forms/form_question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _solidJpeg({
  required int width,
  required int height,
  int quality = 95,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(180, 40, 90));
  // Noise so JPEG does not collapse to a tiny solid block.
  for (var y = 0; y < height; y += 3) {
    for (var x = 0; x < width; x += 3) {
      image.setPixelRgb(x, y, (x * 17) % 255, (y * 13) % 255, (x + y) % 255);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

void main() {
  group('FormMediaAnswer', () {
    test('round-trips map with mime, bytesBase64 and optional dims', () {
      const answer = FormMediaAnswer(
        mime: 'image/jpeg',
        bytesBase64: 'aGVsbG8=',
        width: 10,
        height: 20,
      );
      final map = answer.toMap();
      expect(map['mime'], 'image/jpeg');
      expect(map['bytesBase64'], 'aGVsbG8=');
      expect(map['width'], 10);
      expect(map['height'], 20);
      expect(map.containsKey('storagePath'), isFalse);

      final parsed = FormMediaAnswer.fromMap(map);
      expect(parsed, answer);
      expect(parsed.byteLength, 5);
      expect(parsed.isWithinCap, isTrue);
    });

    test('tryParse recognizes media maps and rejects plain strings', () {
      expect(FormMediaAnswer.tryParse('path/ref'), isNull);
      expect(
        FormMediaAnswer.tryParse({
          'mime': 'audio/mp4',
          'bytesBase64': base64Encode(Uint8List.fromList([1, 2, 3])),
        }),
        isNotNull,
      );
      expect(
        FormMediaAnswer.tryParse({'optionId': 'sim'}),
        isNull,
      );
    });
  });

  group('FormMediaCodec.encodeImage', () {
    test('compresses large JPEG under the ~300 KiB cap', () {
      final raw = _solidJpeg(width: 2400, height: 1800, quality: 100);
      expect(raw.lengthInBytes, greaterThan(kFormMediaMaxBytes));

      final encoded = FormMediaCodec.encodeImage(raw);
      expect(encoded.mime, 'image/jpeg');
      expect(encoded.isWithinCap, isTrue);
      expect(encoded.byteLength, lessThanOrEqualTo(kFormMediaMaxBytes));
      expect(encoded.width, isNotNull);
      expect(encoded.height, isNotNull);
      expect(encoded.width! <= 1280 || encoded.height! <= 1280, isTrue);

      final roundTrip = base64Decode(encoded.bytesBase64);
      expect(img.decodeImage(roundTrip), isNotNull);
    });

    test('refuses when even heavy compression stays above a tiny teto', () {
      final raw = _solidJpeg(width: 1600, height: 1200, quality: 95);
      expect(
        () => FormMediaCodec.encodeImage(raw, maxBytes: 64),
        throwsA(isA<FormMediaTooLargeException>()),
      );
    });
  });

  group('FormMediaCodec.encodeRaw / encodeForKind', () {
    test('packs audio under cap and refuses above', () {
      final ok = FormMediaCodec.encodeRaw(
        bytes: Uint8List(1024),
        mime: 'audio/mp4',
      );
      expect(ok.mime, 'audio/mp4');
      expect(ok.byteLength, 1024);

      expect(
        () => FormMediaCodec.encodeRaw(
          bytes: Uint8List(kFormMediaMaxBytes + 1),
          mime: 'video/mp4',
        ),
        throwsA(
          isA<FormMediaTooLargeException>().having(
            (e) => e.byteLength,
            'byteLength',
            kFormMediaMaxBytes + 1,
          ),
        ),
      );
    });

    test('encodeForKind routes image vs audio', () {
      final jpeg = _solidJpeg(width: 200, height: 150);
      final asImage = FormMediaCodec.encodeForKind(
        kind: FormQuestionKind.image,
        bytes: jpeg,
      );
      expect(asImage.mime, 'image/jpeg');

      final asAudio = FormMediaCodec.encodeForKind(
        kind: FormQuestionKind.audio,
        bytes: Uint8List.fromList([9, 8, 7]),
        mime: 'audio/mpeg',
      );
      expect(asAudio.mime, 'audio/mpeg');
      expect(asAudio.byteLength, 3);
    });
  });

  group('FormQuestionKind.isMedia', () {
    test('flags image/audio/video only', () {
      expect(FormQuestionKind.image.isMedia, isTrue);
      expect(FormQuestionKind.audio.isMedia, isTrue);
      expect(FormQuestionKind.video.isMedia, isTrue);
      expect(FormQuestionKind.text.isMedia, isFalse);
      expect(FormQuestionKind.choice.isMedia, isFalse);
    });
  });
}
