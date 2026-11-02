import 'package:conecta_creche/mural/app_notification.dart';
import 'package:conecta_creche/mural/mural_post.dart';
import 'package:conecta_creche/mural/mural_read.dart';
import 'package:conecta_creche/mural/mural_reads_repository.dart';
import 'package:conecta_creche/mural/mural_repository.dart';
import 'package:conecta_creche/mural/notification_repository.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/screens/mural_screen.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  late FakeFirebaseFirestore firestore;
  late MuralRepository repository;
  late MuralReadsRepositoryImpl readsRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = MuralRepository(firestore: firestore);
    readsRepository = MuralReadsRepositoryImpl(firestore: firestore);
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

  testWidgets('expanding post records mural read receipt', (tester) async {
    final postId = await repository.createPost(
      title: 'Festa junina',
      body: 'Corpo completo do comunicado.',
      kind: MuralPostKind.comunicado,
      createdBy: 'gestao',
      releasedAt: DateTime.now().subtract(const Duration(days: 1)),
      effectiveAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(
      _wrap(
        MuralScreen(
          repository: repository,
          authorUid: 'uid-resp',
          muralReadsRepository: readsRepository,
          podePublicar: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Festa junina'));
    await tester.pumpAndSettle();

    final id = MuralRead.docId(
      postId: postId,
      uid: 'uid-resp',
      channel: MuralReadChannel.mural,
    );
    final doc = await firestore.collection('mural_reads').doc(id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['channel'], 'mural');
  });

  testWidgets('gestão sees reader count on expanded post', (tester) async {
    final postId = await repository.createPost(
      title: 'Aviso com leitores',
      body: 'Detalhe com contagem.',
      kind: MuralPostKind.recado,
      createdBy: 'gestao',
      releasedAt: DateTime.now().subtract(const Duration(hours: 2)),
      effectiveAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
    await readsRepository.recordRead(
      postId: postId,
      uid: 'uid-a',
      channel: MuralReadChannel.mural,
    );
    await readsRepository.recordRead(
      postId: postId,
      uid: 'uid-b',
      channel: MuralReadChannel.notification,
      notificationId: 'n1',
    );

    await tester.pumpWidget(
      _wrap(
        MuralScreen(
          repository: repository,
          authorUid: 'uid-gestao',
          muralReadsRepository: readsRepository,
          podePublicar: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aviso com leitores'));
    await tester.pumpAndSettle();

    // Expand também registra a leitura da gestão → 3 leitores distintos.
    expect(find.textContaining('lidos'), findsOneWidget);
    expect(await readsRepository.countReaders(postId), 3);
  });

  testWidgets('expanding linked notification records notification channel',
      (tester) async {
    final postId = await repository.createPost(
      title: 'Post origem',
      body: 'Corpo do post.',
      kind: MuralPostKind.comunicado,
      createdBy: 'gestao',
      releasedAt: DateTime.now().subtract(const Duration(days: 1)),
      effectiveAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    final notifications = NotificationRepository(firestore: firestore);
    final children = ChildRepository(firestore: firestore);
    final presence = PresenceRepository(firestore: firestore);
    final notifId = await notifications.createNotification(
      title: 'Push do mural',
      body: 'Abra o comunicado',
      emittedAt: DateTime.now().subtract(const Duration(hours: 1)),
      userId: 'uid-resp',
      sourceType: NotificationSourceType.muralPost,
      sourceId: postId,
    );

    await tester.pumpWidget(
      _wrap(
        MuralScreen(
          repository: repository,
          authorUid: 'uid-resp',
          role: UserRole.responsavel,
          notificationRepository: notifications,
          muralReadsRepository: readsRepository,
          childRepository: children,
          presenceRepository: presence,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Push do mural'));
    await tester.pumpAndSettle();

    final id = MuralRead.docId(
      postId: postId,
      uid: 'uid-resp',
      channel: MuralReadChannel.notification,
    );
    final doc = await firestore.collection('mural_reads').doc(id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['channel'], 'notification');
    expect(doc.data()!['notificationId'], notifId);
  });
}
