// Lab: grava `notifications/` e tenta FCM HTTP v1 (Admin / ADC).
//
// Uso:
//   dart run tool/send_fcm_notification.dart \
//     --title "Aviso" --body "Texto" --user-id UID
//   dart run tool/send_fcm_notification.dart \
//     --title "Push" --body "Texto" --token DEVICE_TOKEN
//   ./sh/send-fcm-notification.sh --title "..." --body "..." --user-id UID
//
// Sem credencial / sem token FCM: só persiste o doc no feed (graceful).
//
// Credenciais:
//   FIRESTORE_EMULATOR_HOST=host:porta
//   FIREBASE_PROJECT_ID=...
//   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json
//   ou `gcloud auth application-default login`

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed.showHelp) {
    _printUsage();
    exit(0);
  }
  if (parsed.title.isEmpty || parsed.body.isEmpty) {
    stderr.writeln('Obrigatório: --title e --body');
    _printUsage();
    exit(64);
  }

  final client = await LabFirestoreClient.connect();
  try {
    final notificationId = await client.createNotification(
      title: parsed.title,
      body: parsed.body,
      userId: parsed.userId,
      sourceType: parsed.sourceType,
      sourceId: parsed.sourceId,
    );
    stdout.writeln('Notification criada: $notificationId');

    final projectId = client.projectId;
    final accessToken = client.accessToken;
    final tokens = <String>[
      if (parsed.token != null && parsed.token!.isNotEmpty) parsed.token!,
    ];

    if (tokens.isEmpty &&
        parsed.userId != null &&
        parsed.userId!.isNotEmpty &&
        accessToken != null) {
      tokens.addAll(await client.listTokensForUid(parsed.userId!));
    }

    if (accessToken == null || accessToken.isEmpty) {
      stdout.writeln(
        'Sem credencial Admin/ADC: push FCM omitido '
        '(só registro no feed).',
      );
      exit(0);
    }
    if (tokens.isEmpty) {
      stdout.writeln(
        'Nenhum device token: push omitido (doc já no feed).',
      );
      exit(0);
    }

    var ok = 0;
    for (final token in tokens) {
      final sent = await sendFcmHttpV1(
        projectId: projectId,
        accessToken: accessToken,
        token: token,
        title: parsed.title,
        body: parsed.body,
        data: {
          if (parsed.sourceType != null) 'sourceType': parsed.sourceType!,
          if (parsed.sourceId != null) 'sourceId': parsed.sourceId!,
          'notificationId': notificationId,
          'title': parsed.title,
          'body': parsed.body,
        },
      );
      if (sent) {
        ok++;
        stdout.writeln('FCM ok → ${token.substring(0, token.length.clamp(0, 12))}…');
      } else {
        stdout.writeln('FCM falhou / omitido para token.');
      }
    }
    stdout.writeln('Envios aceitos: $ok/${tokens.length}');
  } finally {
    client.close();
  }
}

class _Args {
  const _Args({
    required this.title,
    required this.body,
    required this.userId,
    required this.token,
    required this.sourceType,
    required this.sourceId,
    required this.showHelp,
  });

  final String title;
  final String body;
  final String? userId;
  final String? token;
  final String? sourceType;
  final String? sourceId;
  final bool showHelp;
}

_Args _parseArgs(List<String> args) {
  var title = '';
  var body = '';
  String? userId;
  String? token;
  String? sourceType;
  String? sourceId;
  var showHelp = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String next() {
      if (i + 1 >= args.length) {
        stderr.writeln('Falta valor para $arg');
        exit(64);
      }
      return args[++i];
    }

    switch (arg) {
      case '--title':
        title = next();
      case '--body':
        body = next();
      case '--user-id':
        userId = next();
      case '--token':
        token = next();
      case '--source-type':
        sourceType = next();
      case '--source-id':
        sourceId = next();
      case '--help':
      case '-h':
        showHelp = true;
      default:
        stderr.writeln('Argumento desconhecido: $arg');
        _printUsage();
        exit(64);
    }
  }

  return _Args(
    title: title,
    body: body,
    userId: userId,
    token: token,
    sourceType: sourceType,
    sourceId: sourceId,
    showHelp: showHelp,
  );
}

void _printUsage() {
  stdout.writeln('''
Uso: dart run tool/send_fcm_notification.dart --title T --body B [opções]

  --title TEXT       Título da notificação (obrigatório)
  --body TEXT        Corpo (obrigatório)
  --user-id UID      Destinatário do feed (+ tokens desse uid)
  --token TOKEN      Device token FCM explícito
  --source-type STR  mural_post | incident | …
  --source-id ID     Id da origem
  -h, --help         Esta ajuda

Sem GOOGLE_APPLICATION_CREDENTIALS / ADC: só grava o doc no feed.
''');
}

/// Envio FCM HTTP v1. Retorna false em qualquer falha (não lança).
Future<bool> sendFcmHttpV1({
  required String projectId,
  required String accessToken,
  required String token,
  required String title,
  required String body,
  Map<String, String> data = const {},
}) async {
  final uri = Uri.parse(
    'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
  );
  final payload = {
    'message': {
      'token': token,
      'notification': {'title': title, 'body': body},
      if (data.isNotEmpty) 'data': data,
      'android': {
        'priority': 'HIGH',
        'notification': {
          'channel_id': 'conecta_creche_default',
        },
      },
    },
  };

  final client = HttpClient();
  try {
    final req = await client.postUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(payload)));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return true;
    }
    stderr.writeln('FCM HTTP ${res.statusCode}: $text');
    return false;
  } on Object catch (error) {
    stderr.writeln('FCM erro: $error');
    return false;
  } finally {
    client.close(force: true);
  }
}

class LabFirestoreClient {
  LabFirestoreClient._({
    required this.baseUrl,
    required this.projectId,
    required HttpClient http,
    this.accessToken,
  }) : _http = http;

  final String baseUrl;
  final String projectId;
  final String? accessToken;
  final HttpClient _http;

  static Future<LabFirestoreClient> connect() async {
    final env = Platform.environment;
    final projectId = env['FIREBASE_PROJECT_ID'] ??
        env['GCLOUD_PROJECT'] ??
        env['GOOGLE_CLOUD_PROJECT'];
    final emulator = env['FIRESTORE_EMULATOR_HOST'];

    if (emulator != null && emulator.isNotEmpty) {
      final resolved = (projectId == null || projectId.isEmpty)
          ? 'conecta-creche-emulator'
          : projectId;
      final base =
          'http://$emulator/v1/projects/$resolved/databases/(default)/documents';
      stdout.writeln('Usando emulador Firestore em $emulator ($resolved)');
      return LabFirestoreClient._(
        baseUrl: base,
        projectId: resolved,
        http: HttpClient(),
      );
    }

    if (projectId == null || projectId.isEmpty) {
      stderr.writeln(
        'Sem FIREBASE_PROJECT_ID / emulador: não é possível gravar o feed.\n'
        'Defina FIREBASE_PROJECT_ID (+ credenciais) ou FIRESTORE_EMULATOR_HOST.\n'
        'Degradação: nada a persistir neste ambiente.',
      );
      exit(0);
    }

    final token = await _resolveAccessToken();
    final base =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
    return LabFirestoreClient._(
      baseUrl: base,
      projectId: projectId,
      http: HttpClient(),
      accessToken: token,
    );
  }

  void close() => _http.close(force: true);

  Future<String> createNotification({
    required String title,
    required String body,
    String? userId,
    String? sourceType,
    String? sourceId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final fields = <String, dynamic>{
      'title': {'stringValue': title},
      'body': {'stringValue': body},
      'emittedAt': {'timestampValue': now},
      'createdAt': {'timestampValue': now},
    };
    if (userId != null && userId.isNotEmpty) {
      fields['userId'] = {'stringValue': userId};
    }
    if (sourceType != null && sourceType.isNotEmpty) {
      fields['sourceType'] = {'stringValue': sourceType};
    }
    if (sourceId != null && sourceId.isNotEmpty) {
      fields['sourceId'] = {'stringValue': sourceId};
    }

    final uri = Uri.parse('$baseUrl/notifications');
    final req = await _http.postUrl(uri);
    _auth(req);
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode({'fields': fields})));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Firestore create notification ${res.statusCode}: $text');
    }
    final map = jsonDecode(text) as Map<String, dynamic>;
    final name = map['name'] as String? ?? '';
    return name.split('/').last;
  }

  Future<List<String>> listTokensForUid(String uid) async {
    final uri = Uri.parse(
      '$baseUrl/fcm_tokens',
    ).replace(queryParameters: {
      // REST structured query would be heavier; list + filter client-side for lab.
    });
    final req = await _http.getUrl(uri);
    _auth(req);
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      stderr.writeln('List fcm_tokens ${res.statusCode}: $text');
      return const [];
    }
    final map = jsonDecode(text) as Map<String, dynamic>;
    final docs = map['documents'] as List<dynamic>? ?? const [];
    final tokens = <String>[];
    for (final raw in docs) {
      if (raw is! Map<String, dynamic>) continue;
      final fields = raw['fields'] as Map<String, dynamic>? ?? {};
      final docUid = (fields['uid'] as Map?)?['stringValue'] as String?;
      final token = (fields['token'] as Map?)?['stringValue'] as String?;
      if (docUid == uid && token != null && token.isNotEmpty) {
        tokens.add(token);
      }
    }
    return tokens;
  }

  void _auth(HttpClientRequest req) {
    final token = accessToken;
    if (token != null && token.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
  }
}

Future<String?> _resolveAccessToken() async {
  final credPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
  if (credPath != null && credPath.isNotEmpty) {
    // Prefer gcloud ADC helper for SA + user creds alike.
  }
  try {
    final result = await Process.run(
      'gcloud',
      ['auth', 'application-default', 'print-access-token'],
      runInShell: true,
    );
    if (result.exitCode == 0) {
      final token = (result.stdout as String).trim();
      if (token.isNotEmpty) return token;
    }
  } on Object catch (_) {}

  stderr.writeln(
    'Aviso: sem access token (gcloud ADC / service account). '
    'Persistência do feed pode falhar em produção; FCM será omitido.',
  );
  return null;
}
