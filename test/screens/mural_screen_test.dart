import 'package:conecta_creche/mural/mural_post.dart';
import 'package:conecta_creche/mural/mural_repository.dart';
import 'package:conecta_creche/screens/mural_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  late FakeFirebaseFirestore firestore;
  late MuralRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = MuralRepository(firestore: firestore);
  });

  testWidgets('shows released posts ordered by effectiveAt and expands on tap',
      (tester) async {
    final now = DateTime.now();
    await repository.createPost(
      title: 'Antigo',
      body: 'Corpo antigo completo para expandir.',
      kind: MuralPostKind.comunicado,
      createdBy: 'u1',
      releasedAt: now.subtract(const Duration(days: 30)),
      effectiveAt: now.subtract(const Duration(days: 30)),
    );
    await repository.createPost(
      title: 'Evento futuro',
      body: 'Detalhe do evento com local.',
      kind: MuralPostKind.evento,
      createdBy: 'u1',
      releasedAt: now.subtract(const Duration(days: 40)),
      effectiveAt: now.add(const Duration(days: 40)),
      location: 'Parque',
    );
    await repository.createPost(
      title: 'Ainda não liberado',
      body: 'Não deve aparecer para leitura.',
      kind: MuralPostKind.recado,
      createdBy: 'u1',
      releasedAt: now.add(const Duration(days: 5)),
      effectiveAt: now.add(const Duration(days: 5)),
    );

    await tester.pumpWidget(
      _wrap(
        MuralScreen(
          repository: repository,
          authorUid: 'uid-resp',
          podePublicar: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evento futuro'), findsOneWidget);
    expect(find.text('Antigo'), findsOneWidget);
    expect(find.text('Ainda não liberado'), findsNothing);

    // Compact: body truncated — location hidden until expand.
    expect(find.text('Parque'), findsNothing);

    await tester.tap(find.text('Evento futuro'));
    await tester.pumpAndSettle();

    expect(find.text('Parque'), findsOneWidget);
    expect(find.textContaining('Liberação:'), findsOneWidget);

    final titles = tester
        .widgetList<Text>(find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == 'Evento futuro' || w.data == 'Antigo'),
        ))
        .map((t) => t.data)
        .toList();
    expect(titles.first, 'Evento futuro');
  });

  testWidgets('gestão sees FAB and unreleased posts', (tester) async {
    await repository.createPost(
      title: 'Agendado',
      body: 'Sai depois',
      kind: MuralPostKind.comunicado,
      createdBy: 'gestao',
      releasedAt: DateTime.now().add(const Duration(days: 5)),
      effectiveAt: DateTime.now().add(const Duration(days: 5)),
    );

    await tester.pumpWidget(
      _wrap(
        MuralScreen(
          repository: repository,
          authorUid: 'uid-gestao',
          podePublicar: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nova publicação'), findsOneWidget);
    expect(find.text('Agendado'), findsOneWidget);
    expect(find.textContaining('Agendado · libera'), findsOneWidget);
  });
}
