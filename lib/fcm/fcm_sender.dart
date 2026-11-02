/// Seam de envio FCM (server-side / lab). Mockável em testes.
///
/// No app cliente o default é [NoOpFcmSender]: grava o feed e degrada
/// sem credencial Admin. O script `tool/send_fcm_notification.dart`
/// usa HTTP v1 quando há token.
abstract class FcmSender {
  /// Envia push para um device token. Retorna `true` se o provedor aceitou.
  /// Não deve lançar por falha de rede/credencial — retorna `false`.
  Future<bool> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String> data = const {},
  });
}

/// Sem envio real (lab sem credencial / app cliente).
class NoOpFcmSender implements FcmSender {
  const NoOpFcmSender();

  @override
  Future<bool> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async =>
      false;
}

/// Sender em memória para testes (grava tentativas).
class RecordingFcmSender implements FcmSender {
  RecordingFcmSender({this.succeed = true});

  final bool succeed;
  final List<FcmSendAttempt> attempts = [];

  @override
  Future<bool> sendToToken({
    required String token,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    attempts.add(
      FcmSendAttempt(
        token: token,
        title: title,
        body: body,
        data: Map<String, String>.from(data),
      ),
    );
    return succeed;
  }
}

class FcmSendAttempt {
  const FcmSendAttempt({
    required this.token,
    required this.title,
    required this.body,
    required this.data,
  });

  final String token;
  final String title;
  final String body;
  final Map<String, String> data;
}
