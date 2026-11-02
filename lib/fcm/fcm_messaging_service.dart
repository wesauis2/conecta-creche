import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'fcm_token.dart';
import 'fcm_token_repository.dart';

/// Canal Android estável (wizard: `conecta_creche_default`).
const String kFcmAndroidChannelId = 'conecta_creche_default';
const String kFcmAndroidChannelName = 'Avisos da creche';
const String kFcmAndroidChannelDescription =
    'Notificações de avisos, mural e incidentes.';

/// Handler de background/terminated — isolate separado; sem UI.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } on Object catch (error) {
    debugPrint('FCM background: Firebase indisponível ($error)');
    return;
  }

  final title = message.notification?.title ??
      message.data['title'] as String? ??
      'Conecta Creche';
  final body = message.notification?.body ??
      message.data['body'] as String? ??
      '';
  debugPrint('FCM background: $title — $body');
}

/// Registra/renova token FCM após auth e trata mensagens no Android.
/// Degrada sem lançar se FCM / google-services estiverem ausentes.
class FcmMessagingService {
  FcmMessagingService({
    required FcmTokensRepository tokenRepository,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _tokenRepository = tokenRepository,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final FcmTokensRepository _tokenRepository;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  String? _activeUid;
  String? _currentToken;
  bool _handlersBound = false;
  bool _available = true;

  bool get isAvailable => _available;

  /// Liga ao fluxo de auth: registra após login; limpa token no logout.
  void attachToAuth(Stream<User?> authStateChanges) {
    _authSub?.cancel();
    _authSub = authStateChanges.listen((user) async {
      if (user == null) {
        await clearForLogout();
      } else {
        await registerForUser(user.uid);
      }
    });
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
  }

  Future<void> registerForUser(String uid) async {
    _activeUid = uid;
    if (!_available) return;

    try {
      await _ensureHandlers();
      await _ensureAndroidChannel();
      await _requestPermissionQuietly();

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM: token vazio — push desabilitado neste device.');
        return;
      }

      await _persistToken(uid, token);
      _listenTokenRefresh();
    } on Object catch (error) {
      _available = false;
      debugPrint('FCM indisponível (degradando): $error');
    }
  }

  /// Remove o token deste device do Firestore (logout).
  Future<void> clearForLogout() async {
    final token = _currentToken;
    _activeUid = null;
    _currentToken = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    if (token == null || token.isEmpty) return;
    try {
      await _tokenRepository.deleteToken(token);
    } on Object catch (error) {
      debugPrint('FCM: falha ao limpar token no logout: $error');
    }
  }

  Future<void> _ensureHandlers() async {
    if (_handlersBound) return;
    _handlersBound = true;

    // Background handler: registrar em main() via [bindBackgroundHandler].
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _openedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  /// Chamar uma vez em `main` antes de `runApp` (isolate de background).
  static void bindBackgroundHandler() {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } on Object catch (error) {
      debugPrint('FCM: não foi possível ligar handler de background: $error');
    }
  }

  Future<void> _ensureAndroidChannel() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings: initSettings);

    const channel = AndroidNotificationChannel(
      kFcmAndroidChannelId,
      kFcmAndroidChannelName,
      description: kFcmAndroidChannelDescription,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissionQuietly() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } on Object catch (error) {
      debugPrint('FCM: permissão não concedida ou indisponível: $error');
    }
  }

  void _listenTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      final uid = _activeUid;
      if (uid == null) return;
      try {
        await _persistToken(uid, token);
      } on Object catch (error) {
        debugPrint('FCM: falha ao renovar token: $error');
      }
    });
  }

  Future<void> _persistToken(String uid, String token) async {
    final previous = _currentToken;
    _currentToken = token;
    await _tokenRepository.upsertToken(
      uid: uid,
      token: token,
      platform: _currentPlatform(),
    );
    // Token rotacionou: remove o doc antigo se o id mudou.
    if (previous != null && previous.isNotEmpty && previous != token) {
      try {
        await _tokenRepository.deleteToken(previous);
      } on Object catch (_) {}
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'Conecta Creche';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        '';

    debugPrint('FCM foreground: $title — $body');

    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            kFcmAndroidChannelId,
            kFcmAndroidChannelName,
            channelDescription: kFcmAndroidChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['sourceId'] as String?,
      );
    } on Object catch (error) {
      debugPrint('FCM: não foi possível exibir notificação local: $error');
    }
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    final sourceType = message.data['sourceType'];
    final sourceId = message.data['sourceId'];
    debugPrint(
      'FCM aberta: sourceType=$sourceType sourceId=$sourceId',
    );
  }

  FcmPlatform _currentPlatform() {
    if (kIsWeb) return FcmPlatform.other;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => FcmPlatform.android,
      TargetPlatform.iOS => FcmPlatform.ios,
      _ => FcmPlatform.other,
    };
  }
}
