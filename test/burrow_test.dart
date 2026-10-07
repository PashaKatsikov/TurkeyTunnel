import 'package:flutter_test/flutter_test.dart';
import 'package:turkey_tunnel/offramp/vault/junction_env.dart';
import 'package:turkey_tunnel/offramp/vault/stowed_bytes.dart';

// Exercises the native `burrow` guard end-to-end through the FFI
// bindings: the host library is built by hook/build.dart and the
// strings must round-trip out of their obfuscated byte arrays.
void main() {
  test('the guard reveals the edge endpoint and UA fragments', () {
    expect(pullSyncUrl(), startsWith('https://'));
    expect(pullMarkProduct(), 'Mozilla/5.0');
    expect(pullMarkPlatformEnd(), ')');
    expect(pullWebkitRev(), '537.36');
  });

  test('the guard reveals the opt-in copy and the keyboard enhancer', () {
    expect(pullOptinTitle(), contains('NOTIFICATIONS'));
    expect(pullOptinBody(), isNotEmpty);
    // The keyboard reveal enhancer exposes the window hook Flutter calls
    // and drives off the live visual viewport.
    final String kbd = pullTweakKeyboard();
    expect(kbd, contains('__ttxSeat'));
    expect(kbd, contains('visualViewport'));
    // Bridge names must round-trip to the exact strings MainActivity.kt
    // rebuilds from char codes, or the native channel never binds.
    expect(pullIoChannel(), 'junction/io');
    expect(pullIoPick(), 'pick');
    expect(pullIoIme(), 'ime');
    expect(pullIoCloak(), 'cloak');
  });

  test('gray-part constants decode from the guard', () {
    expect(JunctionEnv.optinSnoozeSeconds, 258972);
    expect(JunctionEnv.nativeRetryGapSeconds, 3);
    expect(JunctionEnv.reachDropDebounceMs, 950);
    expect(JunctionEnv.envelopeRev, 17);
    expect(JunctionEnv.fieldSchema, 'f');
    expect(JunctionEnv.fieldTag, 'd');
  });
}
