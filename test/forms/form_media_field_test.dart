import 'dart:typed_data';

import 'package:conecta_creche/forms/form_media_answer.dart';
import 'package:conecta_creche/forms/form_media_field.dart';
import 'package:conecta_creche/forms/form_question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _tinyJpeg() {
  final image = img.Image(width: 32, height: 24);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 70));
}

void main() {
  tearDown(() {
    formMediaBytesPickerOverride = null;
  });

  testWidgets('mostra copy Spark/Storage e grava valor estruturado',
      (tester) async {
    FormMediaAnswer? current;

    formMediaBytesPickerOverride = (kind) async {
      expect(kind, FormQuestionKind.image);
      return FormMediaPick(bytes: _tinyJpeg(), mime: 'image/jpeg');
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FormMediaField(
                kind: FormQuestionKind.image,
                value: current,
                onChanged: (v) => setState(() => current = v),
              );
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('plano free/Spark'), findsOneWidget);
    expect(find.textContaining('Cloud Storage'), findsOneWidget);

    await tester.tap(find.text('Anexar imagem'));
    await tester.pumpAndSettle();

    expect(current, isNotNull);
    expect(current!.mime, 'image/jpeg');
    expect(current!.bytesBase64, isNotEmpty);
    expect(current!.isWithinCap, isTrue);
    expect(find.textContaining('Imagem'), findsWidgets);
  });

  testWidgets('recusa anexo acima do teto e limpa valor', (tester) async {
    FormMediaAnswer? current = const FormMediaAnswer(
      mime: 'audio/mp4',
      bytesBase64: 'AAA=',
    );

    formMediaBytesPickerOverride = (_) async {
      return FormMediaPick(
        bytes: Uint8List(kFormMediaMaxBytes + 50),
        mime: 'audio/mp4',
      );
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FormMediaField(
                kind: FormQuestionKind.audio,
                value: current,
                onChanged: (v) => setState(() => current = v),
              );
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('Áudio/vídeo longos'), findsOneWidget);

    await tester.tap(find.text('Anexar áudio'));
    await tester.pumpAndSettle();

    expect(current, isNull);
    expect(find.textContaining('acima do teto'), findsOneWidget);
  });
}
