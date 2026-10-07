import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../vault/junction_env.dart';
import 'outcome.dart';

// ============================================================
// STASH — persisted off-ramp state (prefs + secure storage)
// ============================================================
// Flags and timestamps live in SharedPreferences; URLs live in the
// platform's encrypted store. Every key is a terse token behind a
// random prefix, so a prefs dump reveals no intent.
// ============================================================

// Short random prefix, unrelated to the app slug.
const String _p = 'qz4_';

class Stash {
  Stash({FlutterSecureStorage? secure})
      : _safe = secure ?? const FlutterSecureStorage();

  static const String _kLane = '${_p}ln';
  static const String _kTarget = '${_p}tg';
  static const String _kTargetTtl = '${_p}tg_ttl';
  static const String _kOptinUntil = '${_p}op_until';
  static const String _kOptinOk = '${_p}op_ok';
  static const String _kOptinOsNo = '${_p}op_osno';
  static const String _kPending = '${_p}pend';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _safe;

  Future<void> warm() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Lane memory ──────────────────────────────────────────
  LaneMemory get lane => LaneMemory.read(_prefs.getString(_kLane));

  Future<void> saveLane(LaneMemory value) =>
      _prefs.setString(_kLane, value.wire);

  // ── Cached target URL (secure) ───────────────────────────
  Future<String?> cachedTarget() => _safe.read(key: _kTarget);

  Future<void> cacheTarget(String url, int? expiresUnix) async {
    await _safe.write(key: _kTarget, value: url);
    await _prefs.setInt(
      _kTargetTtl,
      expiresUnix ?? (_now() + JunctionEnv.cachedUrlTtlSeconds),
    );
  }

  bool get cachedTargetStale {
    final int? until = _prefs.getInt(_kTargetTtl);
    if (until == null) return true;
    return _now() >= until;
  }

  // ── Opt-in stage state ───────────────────────────────────
  bool get optinGranted => _prefs.getBool(_kOptinOk) ?? false;

  Future<void> markOptinGranted(bool value) =>
      _prefs.setBool(_kOptinOk, value);

  bool get optinBlockedByOs => _prefs.getBool(_kOptinOsNo) ?? false;

  Future<void> markOptinBlockedByOs() => _prefs.setBool(_kOptinOsNo, true);

  Future<void> writeOptinSnoozeUntil(int unixSeconds) =>
      _prefs.setInt(_kOptinUntil, unixSeconds);

  /// Should the push opt-in promo appear before the WebView?
  bool get shouldOfferOptin {
    if (optinGranted) return false;
    if (optinBlockedByOs) return false;
    final int? until = _prefs.getInt(_kOptinUntil);
    if (until == null) return true;
    return _now() >= until;
  }

  // ── One-shot push URL (secure) ───────────────────────────
  Future<void> stashPending(String? url) async {
    if (url == null || url.isEmpty) {
      await _safe.delete(key: _kPending);
    } else {
      await _safe.write(key: _kPending, value: url);
    }
  }

  Future<String?> takePending() async {
    final String? url = await _safe.read(key: _kPending);
    if (url != null) await _safe.delete(key: _kPending);
    return url;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
