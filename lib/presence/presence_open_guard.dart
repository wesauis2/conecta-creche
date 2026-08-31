/// Thrown when an arrival would create a second open presence record for
/// the same child on the same civil day ("dia civil"). See CONTEXT.md
/// "Registro aberto".
class OpenPresenceRecordException implements Exception {
  const OpenPresenceRecordException(this.childId, this.dayKey);

  final String childId;
  final String dayKey;

  @override
  String toString() =>
      'Já existe um registro de presença aberto para a criança '
      '$childId em $dayKey.';
}

/// Pure domain rule for the "open-guard": at most one **open** presence
/// record per (`childId`, `dayKey`). Multiple records per child per day are
/// allowed as long as previous ones are closed (see SPEC.md).
///
/// Kept free of `cloud_firestore` so it can be unit tested without a live
/// Firebase project; the repository is responsible for determining
/// [hasOpenRecordForDay] (e.g. via a query) before writing.
class PresenceOpenGuard {
  PresenceOpenGuard._();

  static void ensureCanCreateArrival({
    required String childId,
    required String dayKey,
    required bool hasOpenRecordForDay,
  }) {
    if (hasOpenRecordForDay) {
      throw OpenPresenceRecordException(childId, dayKey);
    }
  }
}
