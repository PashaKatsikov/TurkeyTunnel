// Bindings for native/burrow, the gray-part string vault, bundled by
// hook/build.dart. One keyed export hands back a de-obfuscated string
// per call; the selector numbers mirror vault.rs / tool/burrow_gen.dart.
//
// The plaintext never exists as a Dart literal and never lives in a
// native `static` — it is rebuilt on each call and freed immediately.
@DefaultAsset('package:turkey_tunnel/burrow')
library;

import 'dart:convert';
import 'dart:ffi';

@Native<Pointer<Uint8> Function(Uint32)>(symbol: 'bw_s', isLeaf: true)
external Pointer<Uint8> _bwS(int sel);

@Native<Void Function(Pointer<Uint8>)>(symbol: 'bw_free', isLeaf: true)
external void _bwFree(Pointer<Uint8> ptr);

/// Selector numbers — keep in sync with vault.rs and burrow_gen.dart.
abstract final class Sel {
  static const int syncUrl = 1;
  static const int sealKey = 2;
  static const int gcdBase = 3;
  static const int trackKey = 4;
  static const int fcmProject = 5;
  static const int markProduct = 6;
  static const int markPlatform = 7;
  static const int markBuildTag = 8;
  static const int markPlatformEnd = 9;
  static const int markEngine = 10;
  static const int markEngineTail = 11;
  static const int markVendor = 12;
  static const int markMobile = 13;
  static const int chromeRev = 14;
  static const int webkitRev = 15;
  static const int tweakSafeArea = 16;
  static const int tweakAutoplay = 17;
  static const int tweakKeyboard = 18;
  static const int optinTitle = 19;
  static const int optinBody = 20;
  static const int optinSnoozeSeconds = 21;
  static const int organicRescueDelay = 22;
  static const int decisionTimeoutSeconds = 23;
  static const int firstInstallWaitSeconds = 24;
  static const int returningInstallWaitSeconds = 25;
  static const int deepLinkWaitSeconds = 26;
  static const int reachTimeoutSeconds = 27;
  static const int reachDropDebounceMs = 28;
  static const int redirectLoopRetries = 29;
  static const int cachedUrlTtlSeconds = 30;
  static const int nativeRetryGapSeconds = 31;
  static const int envelopeRev = 32;
  static const int fieldSchema = 33;
  static const int fieldNonce = 34;
  static const int fieldPayload = 35;
  static const int fieldTag = 36;
  static const int tweakSeatHook = 37;
  static const int ioChannel = 38;
  static const int ioPick = 39;
  static const int ioIme = 40;
  static const int ioCloak = 41;
}

/// De-obfuscates the string for [sel]. Returns "" for an unknown or
/// empty slot — every caller degrades gracefully on an empty value.
String reveal(int sel) {
  final Pointer<Uint8> p = _bwS(sel);
  if (p == nullptr) return '';
  try {
    int len = 0;
    while (p[len] != 0) {
      len++;
    }
    if (len == 0) return '';
    // Decode copies into a Dart String before the pointer is freed.
    return utf8.decode(p.asTypedList(len));
  } finally {
    _bwFree(p);
  }
}
