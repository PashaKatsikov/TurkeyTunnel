// Bindings for native/burrow, the gray-part string vault, bundled by
// hook/build.dart. One keyed export hands back a de-obfuscated string
// per call; the selector numbers mirror vault.rs / tool/burrow_gen.dart.
//
// The plaintext never exists as a Dart literal and never lives in a
// native `static` — it is rebuilt on each call and freed immediately.
@DefaultAsset('package:turkey_tunnel/turkey_core')
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

@Native<Pointer<Uint8> Function(Uint32)>(symbol: 'bw_s', isLeaf: true)
external Pointer<Uint8> _bwS(int sel);

@Native<Void Function(Pointer<Uint8>)>(symbol: 'bw_free', isLeaf: true)
external void _bwFree(Pointer<Uint8> ptr);

@Native<Uint32 Function(Uint32)>(symbol: 'bw_len', isLeaf: true)
external int _bwLen(int sel);

@Native<Pointer<Uint8> Function(Pointer<Uint8>, UintPtr, Pointer<Uint8>, UintPtr)>(
  symbol: 'bw_ask',
)
external Pointer<Uint8> _bwAsk(
  Pointer<Uint8> body,
  int bodyLen,
  Pointer<Uint8> ua,
  int uaLen,
);

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
  static const int postMethod = 42;
  static const int hdrAccept = 43;
  static const int hdrContentType = 44;
  static const int hdrUserAgent = 45;
  static const int mimeJson = 46;
}

/// Plain config POST, issued inside the guard. [body] is the attribution
/// JSON; [ua] is the device User-Agent. The endpoint never crosses back
/// into Dart. Runs off the UI isolate because the call blocks on the
/// network. [code] 0 means the guard could not complete the call.
Future<ConfigReply> deliverConfig(Uint8List body, String ua) {
  return Isolate.run(() => _deliverConfig(body, ua));
}

class ConfigReply {
  const ConfigReply(this.code, this.payload);

  final int code;
  final String payload;
}

ConfigReply _deliverConfig(Uint8List body, String ua) {
  final Uint8List agent = Uint8List.fromList(utf8.encode(ua));
  final Pointer<Uint8> bodyPtr = _copy(body);
  final Pointer<Uint8> uaPtr = _copy(agent);
  try {
    final Pointer<Uint8> raw = _bwAsk(bodyPtr, body.length, uaPtr, agent.length);
    if (raw == nullptr) return const ConfigReply(0, '');
    try {
      int len = 0;
      while (raw[len] != 0) {
        len++;
      }
      if (len == 0) return const ConfigReply(0, '');
      final String packed = utf8.decode(raw.asTypedList(len));
      final int split = packed.indexOf('\n');
      if (split <= 0) return const ConfigReply(0, '');
      final int code = int.tryParse(packed.substring(0, split)) ?? 0;
      return ConfigReply(code, packed.substring(split + 1));
    } finally {
      _bwFree(raw);
    }
  } finally {
    if (body.isNotEmpty) malloc.free(bodyPtr);
    if (agent.isNotEmpty) malloc.free(uaPtr);
  }
}

Pointer<Uint8> _copy(Uint8List bytes) {
  if (bytes.isEmpty) return nullptr;
  final Pointer<Uint8> ptr = malloc<Uint8>(bytes.length);
  ptr.asTypedList(bytes.length).setAll(0, bytes);
  return ptr;
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

/// Plaintext length of [sel], or 0 when the slot is empty. Does not
/// copy the characters into a Dart string.
int revealLen(int sel) => _bwLen(sel);
