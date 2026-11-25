// Logika lockout PIN — murni, tanpa Flutter/IO.
//
// PinLockout.highWaterMs menyimpan waktu dinding tertinggi yang pernah
// terlihat. Waktu efektif = max(now, highWater). Menurunkan jam perangkat
// tidak memperpendek lockout karena batas bawah tetap puncak waktu yang
// sudah tercatat; memajukan jam justru menaikkan puncak itu.

class PinLockout {
  final int failCount;
  final int level;
  final int lockUntilMs;
  final int highWaterMs;

  const PinLockout({
    this.failCount = 0,
    this.level = 0,
    this.lockUntilMs = 0,
    this.highWaterMs = 0,
  });
}

class PinFailureResult {
  final PinLockout state;
  final bool locked;
  final int lockSeconds;

  const PinFailureResult({
    required this.state,
    required this.locked,
    required this.lockSeconds,
  });
}

const int pinMaxAttempts = 5;
const int pinBaseLockSeconds = 60;
const int pinMaxLockSeconds = 86400;

int effectiveNowMs(int nowMs, int highWaterMs) =>
    nowMs > highWaterMs ? nowMs : highWaterMs;

/// Durasi lockout bertingkat: level 1 = 60 dtk, lalu 2x tiap level,
/// dipotong di 24 jam. Level 0 berarti belum pernah terkunci.
int pinLockSeconds(int level) {
  if (level <= 0) return 0;
  var seconds = pinBaseLockSeconds;
  var current = 1;
  while (current < level && seconds < pinMaxLockSeconds) {
    seconds *= 2;
    current++;
  }
  return seconds > pinMaxLockSeconds ? pinMaxLockSeconds : seconds;
}

bool pinIsLockedOut(PinLockout state, int nowMs) =>
    effectiveNowMs(nowMs, state.highWaterMs) < state.lockUntilMs;

/// Catat satu PIN salah. Percobaan ke-5 (dan kelipatannya, karena
/// failCount di-reset setelah terkunci) memicu lockout level berikutnya.
PinFailureResult pinRegisterFailure(PinLockout state, int nowMs) {
  final now = effectiveNowMs(nowMs, state.highWaterMs);
  final fail = state.failCount + 1;
  if (fail < pinMaxAttempts) {
    return PinFailureResult(
      locked: false,
      lockSeconds: 0,
      state: PinLockout(
        failCount: fail,
        level: state.level,
        lockUntilMs: state.lockUntilMs,
        highWaterMs: now,
      ),
    );
  }
  final level = state.level + 1;
  final seconds = pinLockSeconds(level);
  return PinFailureResult(
    locked: true,
    lockSeconds: seconds,
    state: PinLockout(
      failCount: 0,
      level: level,
      lockUntilMs: now + seconds * 1000,
      highWaterMs: now,
    ),
  );
}

/// PIN benar: reset counter & level, pertahankan high-water.
PinLockout pinRegisterSuccess(PinLockout state, int nowMs) => PinLockout(
      highWaterMs: effectiveNowMs(nowMs, state.highWaterMs),
    );