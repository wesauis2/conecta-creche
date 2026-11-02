import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'form_question.dart';

/// Teto por anexo após compressão (~300 KiB). Ver
/// `docs/requisitos/formularios-configuraveis.md`.
const int kFormMediaMaxBytes = 300 * 1024;

/// Copy pt-BR sobre plano Spark (sem Cloud Storage) e migração futura.
const String kFormMediaSparkNotice =
    'O anexo fica no banco (plano free/Spark; sem Cloud Storage). '
    'Arquivos grandes podem falhar. No futuro: Storage (Blaze).';

/// Copy curta para áudio/vídeo (trechos longos desencorajados no Firestore).
const String kFormMediaAvDiscourageNotice =
    'Áudio/vídeo longos não cabem bem no plano free — prefira trecho curto ou texto.';

/// Valor estruturado de answer para kinds imagem/áudio/vídeo.
/// Persistido em `value` como mapa (não string solta).
///
/// Shape: `{ mime, bytesBase64, width?, height?, storagePath? }`.
class FormMediaAnswer {
  const FormMediaAnswer({
    required this.mime,
    required this.bytesBase64,
    this.width,
    this.height,
    this.storagePath,
  });

  final String mime;
  final String bytesBase64;
  final int? width;
  final int? height;

  /// Reservado para migração futura ao Cloud Storage (Blaze).
  final String? storagePath;

  int get byteLength {
    try {
      return base64Decode(bytesBase64).length;
    } on FormatException {
      return 0;
    }
  }

  bool get isWithinCap => byteLength <= kFormMediaMaxBytes;

  String get displayLabel {
    final kib = (byteLength / 1024).toStringAsFixed(0);
    final kind = mime.startsWith('image/')
        ? 'Imagem'
        : mime.startsWith('audio/')
            ? 'Áudio'
            : mime.startsWith('video/')
                ? 'Vídeo'
                : 'Anexo';
    final dims = (width != null && height != null) ? ' ${width}×$height' : '';
    return '$kind$dims · ${kib} KiB';
  }

  Map<String, dynamic> toMap() => {
        'mime': mime,
        'bytesBase64': bytesBase64,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (storagePath != null) 'storagePath': storagePath,
      };

  factory FormMediaAnswer.fromMap(Map<String, dynamic> map) {
    return FormMediaAnswer(
      mime: map['mime'] as String? ?? 'application/octet-stream',
      bytesBase64: map['bytesBase64'] as String? ?? '',
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      storagePath: map['storagePath'] as String?,
    );
  }

  /// Interpreta [value] Firestore (mapa de mídia) ou retorna null.
  static FormMediaAnswer? tryParse(Object? value) {
    if (value is! Map) return null;
    final map = value is Map<String, dynamic>
        ? value
        : Map<String, dynamic>.from(value);
    final mime = map['mime'];
    final b64 = map['bytesBase64'];
    if (mime is! String || b64 is! String) return null;
    if (mime.isEmpty || b64.isEmpty) return null;
    return FormMediaAnswer.fromMap(map);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormMediaAnswer &&
          mime == other.mime &&
          bytesBase64 == other.bytesBase64 &&
          width == other.width &&
          height == other.height &&
          storagePath == other.storagePath;

  @override
  int get hashCode =>
      Object.hash(mime, bytesBase64, width, height, storagePath);
}

/// Recusa gravação quando o anexo (após compressão) ainda excede o teto.
class FormMediaTooLargeException implements Exception {
  FormMediaTooLargeException({
    required this.byteLength,
    this.maxBytes = kFormMediaMaxBytes,
  });

  final int byteLength;
  final int maxBytes;

  @override
  String toString() =>
      'FormMediaTooLargeException: $byteLength bytes > teto $maxBytes '
      '(~${(maxBytes / 1024).round()} KiB)';
}

/// Compressão/encoding de anexos para gravação no Firestore (sem Storage).
class FormMediaCodec {
  FormMediaCodec._();

  /// Redimensiona e comprime JPEG até caber no teto; senão lança
  /// [FormMediaTooLargeException].
  static FormMediaAnswer encodeImage(
    Uint8List source, {
    int maxBytes = kFormMediaMaxBytes,
    int maxEdge = 1280,
  }) {
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw const FormatException('Imagem inválida ou formato não suportado');
    }

    var working = decoded;
    final longest = working.width > working.height ? working.width : working.height;
    if (longest > maxEdge) {
      working = img.copyResize(
        working,
        width: working.width >= working.height ? maxEdge : null,
        height: working.height > working.width ? maxEdge : null,
        interpolation: img.Interpolation.average,
      );
    }

    // Qualidade decrescente; se ainda passar, reduz a aresta.
    for (var edgePass = 0; edgePass < 4; edgePass++) {
      if (edgePass > 0) {
        final nextEdge = (maxEdge / (edgePass + 1)).round().clamp(320, maxEdge);
        working = img.copyResize(
          working,
          width: working.width >= working.height ? nextEdge : null,
          height: working.height > working.width ? nextEdge : null,
          interpolation: img.Interpolation.average,
        );
      }
      for (final quality in const [85, 70, 55, 40, 28]) {
        final encoded = Uint8List.fromList(
          img.encodeJpg(working, quality: quality),
        );
        if (encoded.lengthInBytes <= maxBytes) {
          return FormMediaAnswer(
            mime: 'image/jpeg',
            bytesBase64: base64Encode(encoded),
            width: working.width,
            height: working.height,
          );
        }
      }
    }

    final lastTry = Uint8List.fromList(img.encodeJpg(working, quality: 20));
    throw FormMediaTooLargeException(byteLength: lastTry.lengthInBytes, maxBytes: maxBytes);
  }

  /// Áudio/vídeo (ou bytes já finais): só empacota se couber no teto.
  static FormMediaAnswer encodeRaw({
    required Uint8List bytes,
    required String mime,
    int maxBytes = kFormMediaMaxBytes,
    int? width,
    int? height,
  }) {
    if (bytes.lengthInBytes > maxBytes) {
      throw FormMediaTooLargeException(
        byteLength: bytes.lengthInBytes,
        maxBytes: maxBytes,
      );
    }
    return FormMediaAnswer(
      mime: mime,
      bytesBase64: base64Encode(bytes),
      width: width,
      height: height,
    );
  }

  /// Codifica conforme [kind]; imagem passa por compressão.
  static FormMediaAnswer encodeForKind({
    required FormQuestionKind kind,
    required Uint8List bytes,
    String? mime,
    int maxBytes = kFormMediaMaxBytes,
  }) {
    return switch (kind) {
      FormQuestionKind.image => encodeImage(bytes, maxBytes: maxBytes),
      FormQuestionKind.audio => encodeRaw(
          bytes: bytes,
          mime: mime ?? 'audio/mp4',
          maxBytes: maxBytes,
        ),
      FormQuestionKind.video => encodeRaw(
          bytes: bytes,
          mime: mime ?? 'video/mp4',
          maxBytes: maxBytes,
        ),
      _ => throw ArgumentError.value(kind, 'kind', 'não é kind de mídia'),
    };
  }
}

extension FormQuestionKindMediaX on FormQuestionKind {
  bool get isMedia =>
      this == FormQuestionKind.image ||
      this == FormQuestionKind.audio ||
      this == FormQuestionKind.video;
}
