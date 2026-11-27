/// How long the app may stay in the background before it locks again.
const lockGracePeriod = Duration(seconds: 30);

/// Whether the app should lock when the user comes back to it.
///
/// Locks only when the lock is on and the app was away for *more than* the
/// grace period, so a quick app switch does not ask for a fingerprint.
bool shouldLockOnResume({
  required bool enabled,
  required DateTime? backgroundedAt,
  required DateTime now,
  Duration grace = lockGracePeriod,
}) {
  if (!enabled || backgroundedAt == null) return false;
  return now.difference(backgroundedAt) > grace;
}