import 'package:cloud_firestore/cloud_firestore.dart';

import 'parecer.dart';

/// A visit ("registro de presença") in `presence_records/{id}`. Several
/// records per child per civil day are allowed; at most one may be
/// **open** (arrived, no departure yet) for the same `childId`+`dayKey`.
/// See CONTEXT.md "Registro de presença" / "Registro aberto".
class PresenceRecord {
  const PresenceRecord({
    required this.id,
    required this.childId,
    required this.dayKey,
    required this.arrivedAt,
    required this.isOpen,
    this.departedAt,
    this.parecer,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  final String id;
  final String childId;
  final String dayKey;
  final DateTime arrivedAt;
  final DateTime? departedAt;
  final bool isOpen;
  final Parecer? parecer;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  factory PresenceRecord.fromFirestore(String id, Map<String, dynamic> data) {
    final parecerData = data['parecer'] as Map<String, dynamic>?;
    return PresenceRecord(
      id: id,
      childId: data['childId'] as String,
      dayKey: data['dayKey'] as String,
      arrivedAt: (data['arrivedAt'] as Timestamp).toDate(),
      departedAt: (data['departedAt'] as Timestamp?)?.toDate(),
      isOpen: data['isOpen'] as bool,
      parecer: parecerData == null ? null : Parecer.fromMap(parecerData),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
    );
  }

  /// Fields written when a chegada creates a new open record.
  ///
  /// `departedAt` is always written as `null` (never omitted) so equality
  /// filters on it stay reliable; audit fields use `serverTimestamp()`.
  static Map<String, dynamic> toArrivalMap({
    required String childId,
    required String dayKey,
    required DateTime arrivedAt,
    required String createdBy,
  }) {
    final now = FieldValue.serverTimestamp();
    return {
      'childId': childId,
      'dayKey': dayKey,
      'arrivedAt': Timestamp.fromDate(arrivedAt),
      'departedAt': null,
      'isOpen': true,
      'parecer': null,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
      'updatedBy': createdBy,
    };
  }

  /// Fields updated when a saída closes an open record with its parecer.
  ///
  /// Never touches `dayKey`/`arrivedAt`/`childId` (immutable outside admin
  /// flows, out of scope for this ticket).
  static Map<String, dynamic> toDepartureMap({
    required DateTime departedAt,
    required Parecer parecer,
    required String updatedBy,
  }) {
    return {
      'departedAt': Timestamp.fromDate(departedAt),
      'isOpen': false,
      'parecer': parecer.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }
}
