import '../presence/child.dart';
import '../presence/child_repository.dart';
import '../presence/presence_answer.dart';
import '../presence/presence_record.dart';
import '../presence/presence_repository.dart';
import '../users/user_role.dart';
import 'app_notification.dart';
import 'mural_post.dart';
import 'mural_repository.dart';
import 'notification_repository.dart';

/// Tipos misturados na timeline unificada do mural.
enum MuralFeedItemKind { post, notification, presence, incident }

/// Item compacto da timeline (âncora = [effectiveAt]).
class MuralFeedItem {
  const MuralFeedItem({
    required this.id,
    required this.kind,
    required this.effectiveAt,
    required this.title,
    required this.body,
    this.post,
    this.notification,
    this.childId,
    this.childName,
    this.showUnreleasedBadge = false,
  });

  final String id;
  final MuralFeedItemKind kind;
  final DateTime effectiveAt;
  final String title;
  final String body;
  final MuralPost? post;
  final AppNotification? notification;
  final String? childId;
  final String? childName;
  final bool showUnreleasedBadge;
}

/// Registro de presença projetado no feed (responsável).
class MuralFeedPresence {
  const MuralFeedPresence({
    required this.recordId,
    required this.childId,
    required this.childName,
    required this.arrivedAt,
    required this.departedAt,
    required this.isOpen,
  });

  final String recordId;
  final String childId;
  final String childName;
  final DateTime arrivedAt;
  final DateTime? departedAt;
  final bool isOpen;

  DateTime get effectiveAt => departedAt ?? arrivedAt;
}

/// Incidente projetado no feed (responsável).
class MuralFeedIncident {
  const MuralFeedIncident({
    required this.answerId,
    required this.recordId,
    required this.childId,
    required this.childName,
    required this.dayKey,
    required this.prompt,
    required this.displayValue,
    required this.recordedAt,
  });

  final String answerId;
  final String recordId;
  final String childId;
  final String childName;
  final String dayKey;
  final String prompt;
  final String displayValue;
  final DateTime recordedAt;

  DateTime get effectiveAt => recordedAt;
}

/// Merge client-side por efetividade (desc). Ver docs/requisitos/mural.md.
List<MuralFeedItem> mergeMuralFeedItems({
  required List<MuralPost> posts,
  required List<AppNotification> notifications,
  List<MuralFeedPresence> presenceItems = const [],
  List<MuralFeedIncident> incidents = const [],
  bool showUnreleasedPosts = false,
  DateTime? asOf,
}) {
  final now = asOf ?? DateTime.now();
  final items = <MuralFeedItem>[];

  for (final post in posts) {
    items.add(
      MuralFeedItem(
        id: 'post:${post.id}',
        kind: MuralFeedItemKind.post,
        effectiveAt: post.effectiveAt,
        title: post.title,
        body: post.body,
        post: post,
        showUnreleasedBadge:
            showUnreleasedPosts && !post.isReleased(asOf: now),
      ),
    );
  }

  for (final n in notifications) {
    items.add(
      MuralFeedItem(
        id: 'notif:${n.id}',
        kind: MuralFeedItemKind.notification,
        effectiveAt: n.effectiveAt,
        title: n.title,
        body: n.body,
        notification: n,
      ),
    );
  }

  for (final p in presenceItems) {
    final status = p.isOpen ? 'presente' : 'saíu';
    final body = p.departedAt == null
        ? 'Chegada registrada.'
        : 'Chegada e saída no dia.';
    items.add(
      MuralFeedItem(
        id: 'presence:${p.recordId}',
        kind: MuralFeedItemKind.presence,
        effectiveAt: p.effectiveAt,
        title: '${p.childName} — $status',
        body: body,
        childId: p.childId,
        childName: p.childName,
      ),
    );
  }

  for (final i in incidents) {
    items.add(
      MuralFeedItem(
        id: 'incident:${i.recordId}:${i.answerId}',
        kind: MuralFeedItemKind.incident,
        effectiveAt: i.effectiveAt,
        title: '${i.childName} — incidente',
        body: '${i.prompt}: ${i.displayValue}',
        childId: i.childId,
        childName: i.childName,
      ),
    );
  }

  sortMuralFeedItemsByEffectiveAtDesc(items);
  return items;
}

void sortMuralFeedItemsByEffectiveAtDesc(List<MuralFeedItem> items) {
  items.sort((a, b) {
    final byEffective = b.effectiveAt.compareTo(a.effectiveAt);
    if (byEffective != 0) return byEffective;
    return b.id.compareTo(a.id);
  });
}

/// Carrega e mescla posts + notificações (+ presença/incidentes das crianças
/// vinculadas quando o papel é responsável).
class MuralFeedLoader {
  MuralFeedLoader({
    required this.muralRepository,
    required this.notificationRepository,
    required this.childRepository,
    required this.presenceRepository,
  });

  final MuralPostsRepository muralRepository;
  final NotificationsRepository notificationRepository;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;

  Future<List<MuralFeedItem>> load({
    required String uid,
    required UserRole role,
    DateTime? asOf,
    int pageSize = 40,
    DateTime? startAfterEffectiveAt,
    String? startAfterId,
  }) async {
    final now = asOf ?? DateTime.now();
    final includeUnreleased = role.canPublishMural;

    final posts = includeUnreleased
        ? await muralRepository.watchPosts(includeUnreleased: true, asOf: now).first
        : await muralRepository.listVisiblePosts(asOf: now, pageSize: 500);

    final notifications =
        await notificationRepository.listForUser(uid, asOf: now);

    var presenceItems = const <MuralFeedPresence>[];
    var incidents = const <MuralFeedIncident>[];

    if (role == UserRole.responsavel) {
      final children = await childRepository.listChildrenForResponsible(uid);
      final byId = {for (final c in children) c.id: c};
      presenceItems = await _presenceForChildren(children);
      incidents = await _incidentsForChildren(byId);
    }

    final merged = mergeMuralFeedItems(
      posts: posts,
      notifications: notifications,
      presenceItems: presenceItems,
      incidents: incidents,
      showUnreleasedPosts: includeUnreleased,
      asOf: now,
    );

    Iterable<MuralFeedItem> page = merged;
    if (startAfterEffectiveAt != null && startAfterId != null) {
      page = merged.where((item) {
        final cmp = item.effectiveAt.compareTo(startAfterEffectiveAt);
        if (cmp != 0) return cmp < 0;
        return item.id.compareTo(startAfterId) < 0;
      });
    }
    return page.take(pageSize).toList(growable: false);
  }

  Future<List<MuralFeedPresence>> _presenceForChildren(
    List<Child> children,
  ) async {
    final items = <MuralFeedPresence>[];
    for (final child in children) {
      final records =
          await presenceRepository.listByChildId(childId: child.id);
      for (final record in records) {
        items.add(
          MuralFeedPresence(
            recordId: record.id,
            childId: child.id,
            childName: child.name,
            arrivedAt: record.arrivedAt,
            departedAt: record.departedAt,
            isOpen: record.isOpen,
          ),
        );
      }
    }
    return items;
  }

  Future<List<MuralFeedIncident>> _incidentsForChildren(
    Map<String, Child> byId,
  ) async {
    final items = <MuralFeedIncident>[];
    for (final child in byId.values) {
      final found =
          await presenceRepository.listIncidents(childId: child.id);
      for (final incident in found) {
        final at = incident.answer.recordedAt ??
            incident.answer.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        items.add(
          MuralFeedIncident(
            answerId: incident.answer.id,
            recordId: incident.recordId,
            childId: incident.childId,
            childName: child.name,
            dayKey: incident.dayKey,
            prompt: incident.answer.questionSnapshot.prompt,
            displayValue: incident.answer.displayValue,
            recordedAt: at,
          ),
        );
      }
    }
    return items;
  }
}

/// Helpers usados em testes / previews sem tocar Firestore de presença.
MuralFeedItem feedItemFromPost(MuralPost post, {DateTime? asOf}) {
  return MuralFeedItem(
    id: 'post:${post.id}',
    kind: MuralFeedItemKind.post,
    effectiveAt: post.effectiveAt,
    title: post.title,
    body: post.body,
    post: post,
    showUnreleasedBadge: !post.isReleased(asOf: asOf),
  );
}

MuralFeedPresence presenceFromRecord({
  required PresenceRecord record,
  required String childName,
}) {
  return MuralFeedPresence(
    recordId: record.id,
    childId: record.childId,
    childName: childName,
    arrivedAt: record.arrivedAt,
    departedAt: record.departedAt,
    isOpen: record.isOpen,
  );
}

MuralFeedIncident incidentFromPresence({
  required PresenceIncident incident,
  required String childName,
}) {
  return MuralFeedIncident(
    answerId: incident.answer.id,
    recordId: incident.recordId,
    childId: incident.childId,
    childName: childName,
    dayKey: incident.dayKey,
    prompt: incident.answer.questionSnapshot.prompt,
    displayValue: incident.answer.displayValue,
    recordedAt: incident.answer.recordedAt ??
        incident.answer.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
