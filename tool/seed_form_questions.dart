// Seed / replace do pacote default de form_questions (CLI puro Dart).
//
// Uso:
//   dart run tool/seed_form_questions.dart
//   dart run tool/seed_form_questions.dart --replace
//   dart run tool/seed_form_questions.dart --dry-run
//
// Credenciais / projeto locais:
//   - Emulador: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
//     (opcional FIREBASE_PROJECT_ID)
//   - Produção: FIREBASE_PROJECT_ID + token via
//     `gcloud auth application-default print-access-token`
//     ou GOOGLE_APPLICATION_CREDENTIALS (service account JSON).

import 'dart:convert';
import 'dart:io';

import 'package:conecta_creche/forms/default_form_questions.dart';

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed.showHelp) {
    _printUsage();
    exit(0);
  }

  final package = defaultFormQuestionsPackage();

  if (parsed.dryRun) {
    stdout.writeln(
      'Pacote default (${package.length} perguntas) — dry-run, sem gravar:',
    );
    for (final q in package) {
      final flags = <String>[
        if (q.flags.duranteDia) 'durante_dia',
        if (q.flags.saida) 'saida',
        if (q.flags.incident) 'incident',
        if (q.flags.optional) 'optional',
        if (q.flags.oculta) 'oculta',
      ].join(',');
      stdout.writeln(
        '  [${q.sortIndex}] ${q.seedKey}  ${q.kind.firestoreValue}'
        '  flags={$flags}  "${q.prompt}"',
      );
    }
    exit(0);
  }

  final client = await FirestoreRestClient.connect(
    actorUid: parsed.actorUid,
  );
  try {
    final result = parsed.replace
        ? await _replace(client, package)
        : await _safeSeed(client, package);

    stdout.writeln(
      parsed.replace
          ? 'Replace concluído.'
          : 'Seed seguro concluído (idempotente via seedKey).',
    );
    stdout.writeln(
      '  created=${result.created} updated=${result.updated} '
      'deactivated=${result.deactivated} skipped=${result.skipped}',
    );
  } finally {
    client.close();
  }
}

class _Args {
  const _Args({
    required this.replace,
    required this.dryRun,
    required this.showHelp,
    required this.actorUid,
  });

  final bool replace;
  final bool dryRun;
  final bool showHelp;
  final String actorUid;
}

_Args _parseArgs(List<String> args) {
  var replace = false;
  var dryRun = false;
  var showHelp = false;
  var actorUid = Platform.environment['SEED_ACTOR_UID'] ?? 'seed-script';

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--replace':
        replace = true;
      case '--dry-run':
        dryRun = true;
      case '--help':
      case '-h':
        showHelp = true;
      case '--actor':
        if (i + 1 >= args.length) {
          stderr.writeln('Falta valor para --actor');
          exit(64);
        }
        actorUid = args[++i];
      default:
        stderr.writeln('Argumento desconhecido: $arg');
        _printUsage();
        exit(64);
    }
  }

  return _Args(
    replace: replace,
    dryRun: dryRun,
    showHelp: showHelp,
    actorUid: actorUid,
  );
}

void _printUsage() {
  stdout.writeln('''
Uso: dart run tool/seed_form_questions.dart [opções]

  (sem args)   Cria perguntas default ausentes (idempotente via seedKey)
  --replace    Desativa perguntas ativas e regrava o pacote default
  --dry-run    Lista o pacote default sem gravar no Firestore
  --actor UID  Gravado em createdBy/updatedBy (default: seed-script
               ou SEED_ACTOR_UID)
  -h, --help   Esta ajuda

Credenciais/projeto locais:
  FIRESTORE_EMULATOR_HOST=host:porta
  FIREBASE_PROJECT_ID=...
  # produção: gcloud auth application-default login
  # ou GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json
''');
}

class _SeedCounts {
  int created = 0;
  int updated = 0;
  int deactivated = 0;
  int skipped = 0;
}

Future<_SeedCounts> _safeSeed(
  FirestoreRestClient client,
  List<DefaultFormQuestion> package,
) async {
  final existing = await client.listQuestions();
  final bySeedKey = <String, _RemoteQuestion>{};
  for (final q in existing) {
    final key = q.seedKey;
    if (key != null && key.isNotEmpty) {
      bySeedKey.putIfAbsent(key, () => q);
    }
  }

  final counts = _SeedCounts();
  for (final def in package) {
    if (bySeedKey.containsKey(def.seedKey)) {
      counts.skipped++;
      continue;
    }
    await client.createQuestion(def);
    counts.created++;
  }
  return counts;
}

Future<_SeedCounts> _replace(
  FirestoreRestClient client,
  List<DefaultFormQuestion> package,
) async {
  final existing = await client.listQuestions();
  final bySeedKey = <String, _RemoteQuestion>{};
  for (final q in existing) {
    final key = q.seedKey;
    if (key != null && key.isNotEmpty) {
      bySeedKey.putIfAbsent(key, () => q);
    }
  }

  final counts = _SeedCounts();
  for (final q in existing) {
    if (!q.active) continue;
    await client.setActive(q.id, active: false);
    counts.deactivated++;
  }

  for (final def in package) {
    final prior = bySeedKey[def.seedKey];
    if (prior != null) {
      await client.updateQuestion(prior.id, def, active: true);
      counts.updated++;
    } else {
      await client.createQuestion(def);
      counts.created++;
    }
  }
  return counts;
}

class _RemoteQuestion {
  const _RemoteQuestion({
    required this.id,
    required this.active,
    this.seedKey,
  });

  final String id;
  final bool active;
  final String? seedKey;
}

/// Cliente mínimo Firestore REST (sem plugins Flutter).
class FirestoreRestClient {
  FirestoreRestClient._({
    required this.baseUrl,
    required this.actorUid,
    required HttpClient http,
    this.accessToken,
  }) : _http = http;

  final String baseUrl;
  final String actorUid;
  final String? accessToken;
  final HttpClient _http;

  static Future<FirestoreRestClient> connect({
    required String actorUid,
  }) async {
    final env = Platform.environment;
    final projectId = env['FIREBASE_PROJECT_ID'] ??
        env['GCLOUD_PROJECT'] ??
        env['GOOGLE_CLOUD_PROJECT'];
    final emulator = env['FIRESTORE_EMULATOR_HOST'];

    if (emulator != null && emulator.isNotEmpty) {
      final resolvedProject = (projectId == null || projectId.isEmpty)
          ? 'conecta-creche-emulator'
          : projectId;
      final base =
          'http://$emulator/v1/projects/$resolvedProject/databases/(default)/documents';
      stdout.writeln('Usando emulador Firestore em $emulator ($resolvedProject)');
      return FirestoreRestClient._(
        baseUrl: base,
        actorUid: actorUid,
        http: HttpClient(),
      );
    }

    if (projectId == null || projectId.isEmpty) {
      stderr.writeln(
        'Defina FIREBASE_PROJECT_ID (e credenciais) ou '
        'FIRESTORE_EMULATOR_HOST.',
      );
      exit(1);
    }

    final token = await _resolveAccessToken();
    final base =
        'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
    return FirestoreRestClient._(
      baseUrl: base,
      actorUid: actorUid,
      http: HttpClient(),
      accessToken: token,
    );
  }

  void close() => _http.close(force: true);

  Future<List<_RemoteQuestion>> listQuestions() async {
    final questions = <_RemoteQuestion>[];
    String? pageToken;
    do {
      final uri = Uri.parse(
        '$baseUrl/form_questions${pageToken == null ? '' : '?pageToken=${Uri.encodeQueryComponent(pageToken)}'}',
      );
      final json = await _request('GET', uri);
      final docs = json['documents'] as List<dynamic>? ?? const [];
      for (final raw in docs) {
        if (raw is! Map<String, dynamic>) continue;
        final name = raw['name'] as String? ?? '';
        final id = name.split('/').last;
        final fields = raw['fields'] as Map<String, dynamic>? ?? const {};
        questions.add(
          _RemoteQuestion(
            id: id,
            active: _boolField(fields['active']) ?? true,
            seedKey: _stringField(fields['seedKey']),
          ),
        );
      }
      pageToken = json['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return questions;
  }

  Future<void> createQuestion(DefaultFormQuestion def) async {
    final uri = Uri.parse('$baseUrl/form_questions');
    await _request(
      'POST',
      uri,
      body: {
        'fields': _questionFields(def, active: true),
      },
    );
  }

  Future<void> updateQuestion(
    String id,
    DefaultFormQuestion def, {
    required bool active,
  }) async {
    final mask = [
      'prompt',
      'kind',
      'options',
      'defaultOptionId',
      'flags',
      'sortIndex',
      'active',
      'seedKey',
      'updatedAt',
      'updatedBy',
    ].map(Uri.encodeQueryComponent).join('&updateMask.fieldPaths=');
    final uri = Uri.parse(
      '$baseUrl/form_questions/$id?updateMask.fieldPaths=$mask',
    );
    await _request(
      'PATCH',
      uri,
      body: {
        'fields': _questionFields(def, active: active, includeCreateAudit: false),
      },
    );
  }

  Future<void> setActive(String id, {required bool active}) async {
    final uri = Uri.parse(
      '$baseUrl/form_questions/$id'
      '?updateMask.fieldPaths=active'
      '&updateMask.fieldPaths=updatedAt'
      '&updateMask.fieldPaths=updatedBy',
    );
    await _request(
      'PATCH',
      uri,
      body: {
        'fields': {
          'active': {'booleanValue': active},
          'updatedAt': _timestampNow(),
          'updatedBy': {'stringValue': actorUid},
        },
      },
    );
  }

  Map<String, dynamic> _questionFields(
    DefaultFormQuestion def, {
    required bool active,
    bool includeCreateAudit = true,
  }) {
    final fields = <String, dynamic>{
      'prompt': {'stringValue': def.prompt},
      'kind': {'stringValue': def.kind.firestoreValue},
      'options': {
        'arrayValue': {
          'values': def.options
              .map(
                (o) => {
                  'mapValue': {
                    'fields': {
                      'id': {'stringValue': o.id},
                      'label': {'stringValue': o.label},
                    },
                  },
                },
              )
              .toList(),
        },
      },
      'flags': {
        'mapValue': {
          'fields': {
            'durante_dia': {'booleanValue': def.flags.duranteDia},
            'saida': {'booleanValue': def.flags.saida},
            'oculta': {'booleanValue': def.flags.oculta},
            'incident': {'booleanValue': def.flags.incident},
            'optional': {'booleanValue': def.flags.optional},
          },
        },
      },
      'sortIndex': {'integerValue': '${def.sortIndex}'},
      'active': {'booleanValue': active},
      'seedKey': {'stringValue': def.seedKey},
      'updatedAt': _timestampNow(),
      'updatedBy': {'stringValue': actorUid},
    };

    if (def.defaultOptionId != null) {
      fields['defaultOptionId'] = {'stringValue': def.defaultOptionId};
    } else {
      fields['defaultOptionId'] = {'nullValue': null};
    }

    if (includeCreateAudit) {
      fields['createdAt'] = _timestampNow();
      fields['createdBy'] = {'stringValue': actorUid};
    }
    return fields;
  }

  Map<String, dynamic> _timestampNow() => {
        'timestampValue': DateTime.now().toUtc().toIso8601String(),
      };

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final request = await _http.openUrl(method, uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    if (accessToken != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
    }
    if (body != null) {
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close();
    final payload = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      stderr.writeln('Firestore REST $method $uri → ${response.statusCode}');
      stderr.writeln(payload);
      exit(1);
    }
    if (payload.isEmpty) return {};
    return jsonDecode(payload) as Map<String, dynamic>;
  }
}

String? _stringField(Object? field) {
  if (field is Map<String, dynamic>) {
    return field['stringValue'] as String?;
  }
  return null;
}

bool? _boolField(Object? field) {
  if (field is Map<String, dynamic>) {
    return field['booleanValue'] as bool?;
  }
  return null;
}

Future<String> _resolveAccessToken() async {
  final credPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
  if (credPath != null && credPath.isNotEmpty) {
    final file = File(credPath);
    if (!file.existsSync()) {
      stderr.writeln('GOOGLE_APPLICATION_CREDENTIALS não encontrado: $credPath');
      exit(1);
    }
    // Service account JWT é complexo; delegamos ao gcloud quando disponível.
  }

  final gcloud = await _runCapture('gcloud', [
    'auth',
    'application-default',
    'print-access-token',
  ]);
  if (gcloud != null && gcloud.trim().isNotEmpty) {
    return gcloud.trim();
  }

  final gcloudUser = await _runCapture('gcloud', [
    'auth',
    'print-access-token',
  ]);
  if (gcloudUser != null && gcloudUser.trim().isNotEmpty) {
    return gcloudUser.trim();
  }

  stderr.writeln(
    'Não foi possível obter access token. Faça '
    '`gcloud auth application-default login` ou defina '
    'FIRESTORE_EMULATOR_HOST.',
  );
  exit(1);
}

Future<String?> _runCapture(String executable, List<String> args) async {
  try {
    final result = await Process.run(executable, args, runInShell: false);
    if (result.exitCode != 0) return null;
    return result.stdout.toString();
  } catch (_) {
    return null;
  }
}
